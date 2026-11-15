import Foundation

/// Errors surfaced to the UI, always with a human-readable Russian message.
enum APIError: LocalizedError, Equatable {
    case missingKey
    case invalidKey
    case badRequest(String)
    case rateLimited(String)
    case server(Int, String)
    case network(String)
    case decoding(String)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .missingKey:
            return "Не задан API-ключ."
        case .invalidKey:
            return "Ключ не принят сервером. Проверь его и попробуй снова."
        case .badRequest(let message):
            return message
        case .rateLimited(let message):
            return message
        case .server(let code, let message):
            return "Ошибка сервера (\(code)): \(message)"
        case .network(let message):
            return "Сеть недоступна: \(message)"
        case .decoding(let message):
            return "Не удалось разобрать ответ сервера: \(message)"
        case .cancelled:
            return "Запрос отменён."
        }
    }
}

/// One incremental update emitted while a response streams in.
enum StreamEvent: Sendable {
    case reasoning(String)
    case text(String)
    case usage(Usage)
}

struct Usage: Decodable, Sendable, Hashable {
    let promptTokens: Int?
    let completionTokens: Int?
    let totalTokens: Int?

    enum CodingKeys: String, CodingKey {
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
        case totalTokens = "total_tokens"
    }
}

/// Minimal OpenAI-compatible client for the API at `https://api.aikeysforyou.com/v1`.
struct APIClient: Sendable {
    static let defaultBaseURL = URL(string: "https://api.aikeysforyou.com/v1")!

    let apiKey: String
    var baseURL: URL = APIClient.defaultBaseURL
    var timeout: TimeInterval = 120

    // MARK: - Payloads

    private struct ChatRequest: Encodable {
        let model: String
        let messages: [ChatMessage.Payload]
        let stream: Bool
        let temperature: Double
    }

    private struct ChunkResponse: Decodable {
        struct Choice: Decodable {
            struct Delta: Decodable {
                let content: String?
                let reasoningContent: String?
                let role: String?

                enum CodingKeys: String, CodingKey {
                    case content
                    case reasoningContent = "reasoning_content"
                    case role
                }
            }
            let delta: Delta?
            let finishReason: String?

            enum CodingKeys: String, CodingKey {
                case delta
                case finishReason = "finish_reason"
            }
        }
        let choices: [Choice]?
        let usage: Usage?
    }

    private struct ErrorEnvelope: Decodable {
        struct Detail: Decodable {
            let message: String?
            let type: String?
            let code: String?
        }
        let error: Detail?
    }

    // MARK: - Models

    func fetchModels() async throws -> [ModelInfo] {
        var request = URLRequest(url: baseURL.appendingPathComponent("models"))
        request.httpMethod = "GET"
        request.timeoutInterval = 30
        applyAuth(to: &request)

        let (data, response) = try await send(request)
        try validate(response: response, data: data)
        do {
            let decoded = try JSONDecoder().decode(ModelsResponse.self, from: data)
            return (decoded.data ?? decoded.models ?? []).sorted { $0.id < $1.id }
        } catch {
            throw APIError.decoding(error.localizedDescription)
        }
    }

    /// Verifies a key without spending tokens on a completion.
    func validateKey() async throws {
        _ = try await fetchModels()
    }

    // MARK: - Streaming chat

    func streamChat(model: String,
                    messages: [ChatMessage],
                    temperature: Double = 0.7) -> AsyncThrowingStream<StreamEvent, Error> {
        let payload = ChatRequest(
            model: model,
            messages: messages.map(\.payload),
            stream: true,
            temperature: temperature
        )

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    var request = URLRequest(url: baseURL.appendingPathComponent("chat/completions"))
                    request.httpMethod = "POST"
                    request.timeoutInterval = timeout
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                    applyAuth(to: &request)
                    request.httpBody = try JSONEncoder().encode(payload)

                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    guard let http = response as? HTTPURLResponse else {
                        throw APIError.network("нет ответа HTTP")
                    }
                    if !(200...299).contains(http.statusCode) {
                        let body = try await Self.collect(bytes: bytes)
                        throw Self.mapError(status: http.statusCode, body: body)
                    }

                    for try await line in bytes.lines {
                        if Task.isCancelled { break }
                        guard line.hasPrefix("data:") else { continue }
                        let raw = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
                        if raw.isEmpty { continue }
                        if raw == "[DONE]" { break }

                        guard let data = raw.data(using: .utf8) else { continue }
                        guard let chunk = try? JSONDecoder().decode(ChunkResponse.self, from: data) else { continue }

                        if let reasoning = chunk.choices?.first?.delta?.reasoningContent, !reasoning.isEmpty {
                            continuation.yield(.reasoning(reasoning))
                        }
                        if let text = chunk.choices?.first?.delta?.content, !text.isEmpty {
                            continuation.yield(.text(text))
                        }
                        if let usage = chunk.usage {
                            continuation.yield(.usage(usage))
                        }
                    }
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish(throwing: APIError.cancelled)
                } catch let error as APIError {
                    continuation.finish(throwing: error)
                } catch let error as URLError {
                    if error.code == .cancelled {
                        continuation.finish(throwing: APIError.cancelled)
                    } else {
                        continuation.finish(throwing: APIError.network(error.localizedDescription))
                    }
                } catch {
                    continuation.finish(throwing: APIError.network(error.localizedDescription))
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: - Helpers

    private func applyAuth(to request: inout URLRequest) {
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    }

    private func send(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await URLSession.shared.data(for: request)
        } catch let error as URLError where error.code == .cancelled {
            throw APIError.cancelled
        } catch let error as URLError {
            throw APIError.network(error.localizedDescription)
        }
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw APIError.network("нет ответа HTTP")
        }
        guard (200...299).contains(http.statusCode) else {
            throw Self.mapError(status: http.statusCode, body: String(decoding: data, as: UTF8.self))
        }
    }

    private static func collect(bytes: URLSession.AsyncBytes) async throws -> String {
        var data = Data()
        for try await byte in bytes { data.append(byte) }
        return String(decoding: data, as: UTF8.self)
    }

    static func mapError(status: Int, body: String) -> APIError {
        let message = (try? JSONDecoder().decode(ErrorEnvelope.self, from: Data(body.utf8)))?.error?.message
            ?? body.trimmingCharacters(in: .whitespacesAndNewlines)
        let short = message.isEmpty ? "неизвестная ошибка" : String(message.prefix(300))

        switch status {
        case 401, 403:
            return .invalidKey
        case 429:
            return .rateLimited(short)
        case 500...599:
            return .server(status, short)
        default:
            return .badRequest(short)
        }
    }
}
