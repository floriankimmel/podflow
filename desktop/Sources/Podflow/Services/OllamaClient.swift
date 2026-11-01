import Foundation

/// Minimal Ollama HTTP client: model listing, resumable pulls with progress,
/// and text generation for the content pipeline.
struct OllamaClient: Sendable {
    var baseURL: String
    var session: URLSession

    init(baseURL: String = "http://127.0.0.1:11434", session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    enum OllamaError: LocalizedError {
        case unreachable
        case modelMissing(String)
        case badResponse

        var errorDescription: String? {
            switch self {
            case .unreachable: return "Ollama ist nicht erreichbar. Onboarding ausführen."
            case .modelMissing(let model): return "Modell \(model) fehlt in Ollama. Onboarding ausführen."
            case .badResponse: return "Unerwartete Antwort von Ollama."
            }
        }
    }

    func isReachable() async -> Bool {
        guard let url = URL(string: "\(baseURL)/api/tags") else { return false }
        var request = URLRequest(url: url)
        request.timeoutInterval = 3
        do {
            let (_, response) = try await session.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    func installedModels() async throws -> [String] {
        guard let url = URL(string: "\(baseURL)/api/tags") else { throw OllamaError.unreachable }
        let (data, _) = try await session.data(from: url)
        struct Tags: Codable {
            struct Model: Codable { var name: String }
            var models: [Model]?
        }
        let tags = try JSONDecoder().decode(Tags.self, from: data)
        return tags.models?.map(\.name) ?? []
    }

    func hasModel(_ name: String) async -> Bool {
        guard let models = try? await installedModels() else { return false }
        // "qwen2.5:14b-instruct" matches exactly or by repo prefix.
        return models.contains { $0 == name || $0.hasPrefix(name + ":") || name.hasPrefix($0) }
    }

    struct PullProgress: Sendable {
        var status: String
        var completed: Int64?
        var total: Int64?

        var fraction: Double? {
            guard let completed, let total, total > 0 else { return nil }
            return Double(completed) / Double(total)
        }
    }

    /// Pulls a model; Ollama pulls are resumable server-side. Progress lines
    /// stream as JSON objects.
    func pullModel(_ name: String, onProgress: @escaping @Sendable (PullProgress) -> Void) async throws {
        guard let url = URL(string: "\(baseURL)/api/pull") else { throw OllamaError.unreachable }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = try JSONEncoder().encode(["name": name])
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 3600

        let (bytes, response) = try await session.bytes(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw OllamaError.badResponse }

        struct Line: Codable {
            var status: String?
            var completed: Int64?
            var total: Int64?
            var error: String?
        }
        for try await line in bytes.lines {
            guard let data = line.data(using: .utf8),
                  let parsed = try? JSONDecoder().decode(Line.self, from: data) else { continue }
            if let error = parsed.error {
                throw NSError(domain: "Ollama", code: 1, userInfo: [NSLocalizedDescriptionKey: error])
            }
            onProgress(PullProgress(status: parsed.status ?? "", completed: parsed.completed, total: parsed.total))
        }
    }

    /// Non-streaming generation; the content pipeline needs whole documents.
    func generate(model: String, prompt: String) async throws -> String {
        guard let url = URL(string: "\(baseURL)/api/generate") else { throw OllamaError.unreachable }
        struct Request: Codable {
            var model: String
            var prompt: String
            var stream: Bool
        }
        struct Response: Codable {
            var response: String?
            var error: String?
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = try JSONEncoder().encode(Request(model: model, prompt: prompt, stream: false))
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 1800

        let (data, response) = try await session.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            if let parsed = try? JSONDecoder().decode(Response.self, from: data),
               let error = parsed.error, error.contains("not found") {
                throw OllamaError.modelMissing(model)
            }
            throw OllamaError.badResponse
        }
        let parsed = try JSONDecoder().decode(Response.self, from: data)
        if let error = parsed.error { throw NSError(domain: "Ollama", code: 2, userInfo: [NSLocalizedDescriptionKey: error]) }
        return parsed.response ?? ""
    }
}
