import Foundation

/// Auphonic API client for the Video/Auphonic profile (auphonic-video-ingest):
/// creates a production from the configured preset, uploads the finished
/// video, sets metadata (YouTube description when already generated), and
/// starts the production that publishes video → YouTube and audio → server.
struct AuphonicClient: Sendable {
    var baseURL: String
    var username: String
    var password: String
    var session: URLSession

    init(baseURL: String = "https://auphonic.com", username: String, password: String, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.username = username
        self.password = password
        self.session = session
    }

    enum AuphonicError: LocalizedError {
        case misconfigured(String)
        case http(Int, String)

        var errorDescription: String? {
            switch self {
            case .misconfigured(let detail):
                return "Auphonic ist nicht konfiguriert: \(detail)"
            case .http(let code, let body):
                return "Auphonic-Fehler (HTTP \(code)): \(body)"
            }
        }
    }

    private var authHeader: String {
        let credentials = Data("\(username):\(password)".utf8).base64EncodedString()
        return "Basic \(credentials)"
    }

    private func request(path: String, method: String = "GET") throws -> URLRequest {
        guard !username.isEmpty, !password.isEmpty else {
            throw AuphonicError.misconfigured("Benutzername/Passwort fehlen")
        }
        guard let url = URL(string: baseURL + path) else {
            throw AuphonicError.misconfigured("ungültige URL")
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(authHeader, forHTTPHeaderField: "Authorization")
        return request
    }

    private func send(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await session.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(code) else {
            throw AuphonicError.http(code, String(data: data, encoding: .utf8).map { String($0.prefix(300)) } ?? "")
        }
        return data
    }

    struct Production: Codable {
        var uuid: String
    }

    private struct DataEnvelope<T: Codable>: Codable {
        var data: T
    }

    /// Creates a production from a preset with metadata.
    func createProduction(preset: String, title: String, youtubeDescription: String?) async throws -> Production {
        guard !preset.isEmpty else { throw AuphonicError.misconfigured("Preset fehlt") }
        var request = try request(path: "/api/productions.json", method: "POST")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var metadata: [String: Any] = ["title": title]
        if let youtubeDescription {
            metadata["summary"] = youtubeDescription
        }
        let payload: [String: Any] = ["preset": preset, "metadata": metadata]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let data = try await send(request)
        return try JSONDecoder().decode(DataEnvelope<Production>.self, from: data).data
    }

    /// Uploads the finished video file (multipart).
    func uploadVideo(productionUUID: String, fileURL: URL) async throws {
        var request = try request(path: "/api/production/\(productionUUID)/upload.json", method: "POST")
        let boundary = "podflow-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append(Data("--\(boundary)\r\n".utf8))
        body.append(Data("Content-Disposition: form-data; name=\"input_file\"; filename=\"\(fileURL.lastPathComponent)\"\r\n".utf8))
        body.append(Data("Content-Type: application/octet-stream\r\n\r\n".utf8))
        body.append(try Data(contentsOf: fileURL))
        body.append(Data("\r\n--\(boundary)--\r\n".utf8))
        request.httpBody = body
        request.timeoutInterval = 3600
        _ = try await send(request)
    }

    /// Updates production metadata (e.g. the YouTube description generated
    /// after the production started — D4 removes the ordering constraint).
    func updateMetadata(productionUUID: String, youtubeDescription: String) async throws {
        var request = try request(path: "/api/production/\(productionUUID).json", method: "POST")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let payload: [String: Any] = ["metadata": ["summary": youtubeDescription]]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        _ = try await send(request)
    }

    /// Starts the production (outgoing targets publish YouTube + server audio).
    func startProduction(productionUUID: String) async throws {
        let request = try request(path: "/api/production/\(productionUUID)/start.json", method: "POST")
        _ = try await send(request)
    }
}
