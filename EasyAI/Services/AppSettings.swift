import Foundation
import Security

/// App-wide settings persisted to disk, except the secrets.
@MainActor
final class AppSettings: ObservableObject {
    private enum Keys {
        static let settingsFile = "settings.json"
        static let baseURL = "settings.baseURL"
        static let systemPrompt = "settings.systemPrompt"
        static let streaming = "settings.streaming"
        static let defaultModel = "settings.defaultModel"
        static let temperature = "settings.temperature"
        static let endpoint = "settings.endpoint"
    }

    private struct Snapshot: Codable {
        var systemPrompt: String
        var streaming: Bool
        var defaultModel: String
        var temperature: Double
        var endpoint: String
    }

    @Published var systemPrompt: String {
        didSet { persist() }
    }
    @Published var streamingEnabled: Bool {
        didSet { persist() }
    }
    @Published var defaultModel: String {
        didSet { persist() }
    }
    @Published var temperature: Double {
        didSet { persist() }
    }
    @Published var endpoint: String {
        didSet { persist() }
    }
    /// Not persisted on disk — kept in the Keychain only.
    @Published private(set) var apiKey: String

    init() {
        let stored: Snapshot? = LocalStore.load(Snapshot.self, from: Keys.settingsFile)
        systemPrompt = stored?.systemPrompt ?? "Ты полезный ассистент. Отвечай кратко и по делу, на языке пользователя."
        streamingEnabled = stored?.streaming ?? true
        defaultModel = stored?.defaultModel ?? ModelCatalog.defaultModelID
        temperature = stored?.temperature ?? 0.7
        endpoint = stored?.endpoint ?? APIClient.defaultBaseURL.absoluteString
        apiKey = KeychainStore.load() ?? ""
    }

    var hasKey: Bool { !apiKey.isEmpty }

    var baseURL: URL {
        URL(string: endpoint) ?? APIClient.defaultBaseURL
    }

    func setKey(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        apiKey = trimmed
        KeychainStore.save(trimmed)
    }

    func clearKey() {
        apiKey = ""
        KeychainStore.delete()
    }

    func client() -> APIClient? {
        guard hasKey else { return nil }
        return APIClient(apiKey: apiKey, baseURL: baseURL)
    }

    private func persist() {
        let snapshot = Snapshot(
            systemPrompt: systemPrompt,
            streaming: streamingEnabled,
            defaultModel: defaultModel,
            temperature: temperature,
            endpoint: endpoint
        )
        LocalStore.save(snapshot, to: Keys.settingsFile)
    }
}
