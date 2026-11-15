import SwiftUI

struct ChatView: View {
    @EnvironmentObject private var store: ChatStore
    @EnvironmentObject private var settings: AppSettings

    @State private var input: String = ""
    @State private var showChats = false
    @State private var showSettings = false
    @FocusState private var inputFocused: Bool

    private var conversation: Conversation? { store.selectedConversation }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                transcript
                composer
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showChats = true
                    } label: {
                        Image(systemName: "sidebar.left")
                    }
                    .accessibilityLabel("Чаты")
                }

                ToolbarItem(placement: .principal) {
                    modelMenu
                }

                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 14) {
                        Button {
                            store.newConversation(model: settings.defaultModel)
                        } label: {
                            Image(systemName: "square.and.pencil")
                        }
                        .accessibilityLabel("Новый чат")

                        Button {
                            showSettings = true
                        } label: {
                            Image(systemName: "gearshape")
                        }
                        .accessibilityLabel("Настройки")
                    }
                }
            }
            .sheet(isPresented: $showChats) {
                ChatListView()
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .alert("Ошибка",
                   isPresented: Binding(
                       get: { store.lastError != nil },
                       set: { if !$0 { store.lastError = nil } }
                   )) {
                Button("Ок", role: .cancel) { store.lastError = nil }
            } message: {
                Text(store.lastError ?? "")
            }
        }
    }

    // MARK: - Transcript

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 14) {
                    let messages = conversation?.messages ?? []

                    if messages.isEmpty {
                        EmptyChatView { suggestion in
                            input = suggestion
                            send()
                        }
                    }

                    ForEach(messages) { message in
                        MessageBubble(
                            message: message,
                            isStreaming: store.isStreaming
                                && store.streamingConversationID == conversation?.id
                                && message.id == messages.last?.id
                                && message.role == .assistant
                        )
                        .id(message.id)
                    }

                    Color.clear
                        .frame(height: 1)
                        .id(bottomAnchor)
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 12)
            }
            .defaultScrollAnchor(.bottom)
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: conversation?.messages.count) { _, _ in
                scrollToBottom(proxy)
            }
            .onChange(of: conversation?.messages.last?.content) { _, _ in
                if store.isStreaming { scrollToBottom(proxy, animated: false) }
            }
            .overlay(alignment: .bottomTrailing) {
                if (conversation?.messages.count ?? 0) > 3 {
                    Button {
                        scrollToBottom(proxy)
                    } label: {
                        Image(systemName: "arrow.down")
                            .font(.footnote.weight(.semibold))
                            .padding(9)
                            .background(.regularMaterial, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 18)
                    .padding(.bottom, 10)
                }
            }
        }
    }

    private var bottomAnchor: String { "bottom" }

    private func scrollToBottom(_ proxy: ScrollViewProxy, animated: Bool = true) {
        if animated {
            withAnimation(.easeOut(duration: 0.18)) {
                proxy.scrollTo(bottomAnchor, anchor: .bottom)
            }
        } else {
            proxy.scrollTo(bottomAnchor, anchor: .bottom)
        }
    }

    // MARK: - Composer

    private var composer: some View {
        VStack(spacing: 0) {
            Divider()

            HStack(alignment: .bottom, spacing: 10) {
                TextField("Сообщение…", text: $input, axis: .vertical)
                    .lineLimit(1...6)
                    .focused($inputFocused)
                    .submitLabel(.send)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .onSubmit(send)

                if store.isStreaming {
                    Button {
                        store.stopStreaming()
                    } label: {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(Color.secondary.gradient, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Остановить")
                } else {
                    Button {
                        send()
                    } label: {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(
                                input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? AnyShapeStyle(Color.secondary.opacity(0.35))
                                : AnyShapeStyle(Color.accentColor.gradient),
                                in: Circle()
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityLabel("Отправить")
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .background(.bar)
        .onChange(of: store.selectedID) { _, _ in
            inputFocused = false
        }
    }

    private func send() {
        let text = input
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        input = ""
        store.send(text, settings: settings)
    }

    // MARK: - Model picker

    private var modelMenu: some View {
        Menu {
            Picker("Модель", selection: Binding(
                get: { conversation?.model ?? settings.defaultModel },
                set: { newValue in
                    if let id = conversation?.id {
                        store.setModel(newValue, for: id)
                    }
                    settings.defaultModel = newValue
                }
            )) {
                ForEach(store.modelChoices) { model in
                    Text(model.title).tag(model.id)
                }
            }

            Divider()

            Button {
                Task { await store.refreshModels(settings: settings) }
            } label: {
                Label(store.isRefreshingModels ? "Обновляю…" : "Обновить список моделей",
                      systemImage: "arrow.clockwise")
            }
        } label: {
            HStack(spacing: 5) {
                Text(shortModelName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(.primary)
        }
    }

    private var shortModelName: String {
        let id = conversation?.model ?? settings.defaultModel
        return store.modelChoices.first { $0.id == id }?.title ?? id
    }
}
