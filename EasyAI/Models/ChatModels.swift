import Foundation

/// A single chat message exchanged with the API.
struct ChatMessage: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var role: Role
    var content: String
    /// Optional reasoning / "thinking" text returned by some models.
    var reasoning: String?
    var createdAt: Date

    enum Role: String, Codable, Sendable {
        case system
        case user
        case assistant
    }

    init(id: UUID = UUID(),
         role: Role,
         content: String,
         reasoning: String? = nil,
         createdAt: Date = .now) {
        self.id = id
        self.role = role
        self.content = content
        self.reasoning = reasoning
        self.createdAt = createdAt
    }

    /// Payload sent to the API. Reasoning is never sent back.
    struct Payload: Encodable {
        let role: String
        let content: String
    }

    var payload: Payload { Payload(role: role.rawValue, content: content) }
}

/// A whole conversation, persisted locally.
struct Conversation: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var title: String
    var messages: [ChatMessage]
    var model: String
    var createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(),
         title: String = "Новый чат",
         messages: [ChatMessage] = [],
         model: String = ModelCatalog.defaultModelID,
         createdAt: Date = .now,
         updatedAt: Date = .now) {
        self.id = id
        self.title = title
        self.messages = messages
        self.model = model
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// First user line, shortened, used as a title once the chat has content.
    static func derivedTitle(from text: String, limit: Int = 42) -> String {
        let flat = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
        guard !flat.isEmpty else { return "Новый чат" }
        if flat.count <= limit { return flat }
        return String(flat.prefix(limit)).trimmingCharacters(in: .whitespaces) + "…"
    }
}
