import Foundation
import SwiftUI
import Combine

/// Owns the conversation list and drives streaming completions.
@MainActor
final class ChatStore: ObservableObject {
    private enum Keys {
        static let chatsFile = "conversations.json"
    }

    @Published private(set) var conversations: [Conversation] = []
    @Published var selectedID: UUID?
    @Published private(set) var isStreaming = false
    @Published private(set) var streamingConversationID: UUID?
    @Published var lastError: String?
    @Published private(set) var availableModels: [ModelInfo] = []
    @Published private(set) var isRefreshingModels = false

    private var streamTask: Task<Void, Never>?
    private var saveWorkItem: DispatchWorkItem?

    init() {
        load()
        if conversations.isEmpty {
            let fresh = Conversation()
            conversations = [fresh]
            selectedID = fresh.id
            save()
        } else {
            selectedID = sortedConversations.first?.id
        }
    }

    // MARK: - Derived

    var sortedConversations: [Conversation] {
        conversations.sorted { $0.updatedAt > $1.updatedAt }
    }

    var selectedConversation: Conversation? {
        get {
            guard let selectedID else { return nil }
            return conversations.first { $0.id == selectedID }
        }
    }

    var modelChoices: [ModelInfo] {
        if availableModels.isEmpty { return ModelCatalog.suggestions }
        return availableModels
    }

    private func index(of id: UUID) -> Int? {
        conversations.firstIndex { $0.id == id }
    }

    // MARK: - Conversation management

    @discardableResult
    func newConversation(model: String? = nil) -> UUID {
        stopStreaming()
        let conversation = Conversation(model: model ?? defaultModelID)
        conversations.insert(conversation, at: 0)
        selectedID = conversation.id
        save()
        return conversation.id
    }

    func select(_ id: UUID) {
        guard selectedID != id || streamTask == nil else { return }
        stopStreaming()
        selectedID = id
    }

    func delete(_ id: UUID) {
        if streamingConversationID == id { stopStreaming() }
        conversations.removeAll { $0.id == id }
        if selectedID == id {
            selectedID = sortedConversations.first?.id
        }
        if conversations.isEmpty {
            newConversation()
            return
        }
        save()
    }

    func clearAll() {
        stopStreaming()
        conversations = []
        newConversation()
    }

    func rename(_ id: UUID, to title: String) {
        guard let index = index(of: id) else { return }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        conversations[index].title = trimmed.isEmpty ? "Новый чат" : trimmed
        save()
    }

    func setModel(_ model: String, for id: UUID) {
        guard let index = index(of: id) else { return }
        conversations[index].model = model
        save()
    }

    private var defaultModelID: String {
        UserDefaults.standard.string(forKey: "settings.defaultModel") ?? ModelCatalog.defaultModelID
    }

    // MARK: - Prompting

    func send(_ text: String, settings: AppSettings) {
        let prompt = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty, !isStreaming else { return }

        guard let client = settings.client() else {
            lastError = "Сначала введи API-ключ в настройках."
            return
        }

        if selectedID == nil || selectedConversation == nil {
            newConversation(model: settings.defaultModel)
        }
        guard let conversationID = selectedID, let index = index(of: conversationID) else { return }

        // Append the user message and a placeholder assistant message.
        conversations[index].messages.append(ChatMessage(role: .user, content: prompt))
        let assistant = ChatMessage(role: .assistant, content: "")
        conversations[index].messages.append(assistant)
        let assistantID = assistant.id

        if conversations[index].messages.filter({ $0.role == .user }).count == 1 {
            conversations[index].title = Conversation.derivedTitle(from: prompt)
        }
        conversations[index].updatedAt = .now

        var outgoing: [ChatMessage] = []
        if !settings.systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            outgoing.append(ChatMessage(role: .system, content: settings.systemPrompt))
        }
        outgoing.append(contentsOf: conversations[index].messages
            .filter { $0.role != .assistant || !$0.content.isEmpty || !($0.reasoning ?? "").isEmpty })

        let model = conversations[index].model.isEmpty ? settings.defaultModel : conversations[index].model
        lastError = nil
        isStreaming = true
        streamingConversationID = conversationID
        save()

        streamTask = Task { [weak self] in
            guard let self else { return }
            var sawError: String?

            if settings.streamingEnabled {
                let stream = client.streamChat(model: model, messages: outgoing, temperature: settings.temperature)
                do {
                    for try await event in stream {
                        if Task.isCancelled { break }
                        self.apply(event: event, to: conversationID, messageID: assistantID)
                    }
                } catch {
                    sawError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                }
            } else {
                // Non-streaming fallback: single response, then rendered at once.
                do {
                    let answer = try await ChatStore.completeOnce(
                        client: client, model: model, messages: outgoing, temperature: settings.temperature
                    )
                    self.apply(event: .text(answer), to: conversationID, messageID: assistantID)
                } catch {
                    sawError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                }
            }

            self.finishStreaming(conversationID: conversationID,
                                 messageID: assistantID,
                                 error: Task.isCancelled ? nil : sawError)
        }
    }

    func stopStreaming() {
        streamTask?.cancel()
        streamTask = nil
        if let conversationID = streamingConversationID {
            finalizeEmptyAssistant(in: conversationID)
        }
        isStreaming = false
        streamingConversationID = nil
        save()
    }

    /// Re-sends the conversation without the last assistant turn.
    func regenerateLast(settings: AppSettings) {
        guard !isStreaming,
              let conversationID = selectedID,
              let index = index(of: conversationID),
              let lastUser = conversations[index].messages.lastIndex(where: { $0.role == .user })
        else { return }

        conversations[index].messages.removeSubrange((lastUser + 1)...)
        let prompt = conversations[index].messages[lastUser].content
        conversations[index].messages.removeSubrange(lastUser...)
        let visible = conversations[index].messages
        conversations[index].messages = visible
        save()
        send(prompt, settings: settings)
    }

    // MARK: - Streaming plumbing

    private func apply(event: StreamEvent, to conversationID: UUID, messageID: UUID) {
        guard let cIndex = index(of: conversationID),
              let mIndex = conversations[cIndex].messages.firstIndex(where: { $0.id == messageID })
        else { return }

        switch event {
        case .text(let chunk):
            conversations[cIndex].messages[mIndex].content += chunk
        case .reasoning(let chunk):
            let current = conversations[cIndex].messages[mIndex].reasoning ?? ""
            conversations[cIndex].messages[mIndex].reasoning = current + chunk
        case .usage:
            break
        }
        conversations[cIndex].updatedAt = .now
        scheduleSave()
    }

    private func finishStreaming(conversationID: UUID, messageID: UUID, error: String?) {
        if let error, !error.isEmpty {
            lastError = error
            if let cIndex = index(of: conversationID),
               let mIndex = conversations[cIndex].messages.firstIndex(where: { $0.id == messageID }),
               conversations[cIndex].messages[mIndex].content.isEmpty {
                conversations[cIndex].messages.remove(at: mIndex)
            }
        }
        isStreaming = false
        streamingConversationID = nil
        streamTask = nil
        save()
    }

    private func finalizeEmptyAssistant(in conversationID: UUID) {
        guard let cIndex = index(of: conversationID) else { return }
        conversations[cIndex].messages.removeAll {
            $0.role == .assistant && $0.content.isEmpty && ($0.reasoning ?? "").isEmpty
        }
    }

    // MARK: - Models list

    func refreshModels(settings: AppSettings) async {
        guard let client = settings.client(), !isRefreshingModels else { return }
        isRefreshingModels = true
        defer { isRefreshingModels = false }
        do {
            let models = try await client.fetchModels()
            if !models.isEmpty { availableModels = models }
        } catch {
            lastError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    // MARK: - Persistence

    private func scheduleSave() {
        saveWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            Task { @MainActor in self?.save() }
        }
        saveWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: item)
    }

    func save() {
        LocalStore.save(conversations, to: Keys.chatsFile)
    }

    private func load() {
        if let stored: [Conversation] = LocalStore.load([Conversation].self, from: Keys.chatsFile) {
            conversations = stored
        }
    }

    // MARK: - Non-streaming

    private static func completeOnce(client: APIClient,
                                     model: String,
                                     messages: [ChatMessage],
                                     temperature: Double) async throws -> String {
        var answer = ""
        let stream = client.streamChat(model: model, messages: messages, temperature: temperature)
        for try await event in stream {
            if case .text(let chunk) = event { answer += chunk }
        }
        return answer
    }
}
