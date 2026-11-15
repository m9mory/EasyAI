import Foundation

/// Result of fetching `GET /v1/models`.
struct ModelInfo: Identifiable, Codable, Hashable, Sendable {
    let id: String
    var displayName: String?
    var ownedBy: String?
    var contextWindow: Int?
    var maxOutputTokens: Int?
    var supportsStreaming: Bool?
    var supportsReasoning: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case ownedBy = "owned_by"
        case contextWindow = "context_window"
        case maxOutputTokens = "max_output_tokens"
        case supportsStreaming = "supports_streaming"
        case supportsReasoning = "supports_reasoning"
    }

    var title: String {
        if let displayName, !displayName.isEmpty { return displayName }
        return id
    }
}

struct ModelsResponse: Decodable {
    let data: [ModelInfo]?
    let models: [ModelInfo]?
}

enum ModelCatalog {
    /// The user's key is scoped to this model; a plain `deepseek-v4-flash` is
    /// accepted by the gateway too, but the dated id is the explicit one.
    static let defaultModelID = "deepseek-v4-flash"

    static let suggestions: [ModelInfo] = [
        ModelInfo(id: "deepseek-v4-flash", displayName: "DeepSeek V4 Flash", ownedBy: "deepseek"),
        ModelInfo(id: "deepseek-v4-flash-0731", displayName: "DeepSeek V4 Flash (0731)", ownedBy: "deepseek"),
        ModelInfo(id: "deepseek-v4.1-flash-1017", displayName: "DeepSeek V4.1 Flash (1017)", ownedBy: "deepseek"),
        ModelInfo(id: "deepseek-v4-pro-0813", displayName: "DeepSeek V4 Pro (0813)", ownedBy: "deepseek")
    ]

    static func prettyContext(_ tokens: Int?) -> String? {
        guard let tokens, tokens > 0 else { return nil }
        if tokens >= 1_000_000 {
            let value = Double(tokens) / 1_000_000
            return String(format: "%.1fM ctx", value)
        }
        if tokens >= 1_000 {
            return "\(tokens / 1_000)K ctx"
        }
        return "\(tokens) ctx"
    }
}
