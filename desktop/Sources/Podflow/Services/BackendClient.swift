import Foundation

enum BackendError: LocalizedError, Equatable {
    case notConfigured
    case unauthorized
    case notFound
    case http(Int)
    case invalidURL

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "Backend ist nicht konfiguriert."
        case .unauthorized: return "Workspace-Key wurde abgelehnt."
        case .notFound: return "Episode nicht gefunden."
        case .http(let code): return "Backend-Fehler (HTTP \(code))."
        case .invalidURL: return "Ungültige Backend-URL."
        }
    }
}

protocol BackendClientProtocol: Sendable {
    func listEpisodes() async throws -> [BackendEpisode]
    func getEpisode(id: String) async throws -> BackendEpisode
    func reportStep(id: String, step: String, status: StepState, metadata: BackendMetadata) async throws
    func putMetadata(id: String, metadata: BackendMetadata) async throws
    func putContent(id: String, key: String, body: String) async throws
    func deleteEpisode(id: String) async throws
}

struct BackendMetadata: Codable, Sendable {
    var episodeNumber: String?
    var slug: String?
    var title: String?
    var releaseDate: String?
    var profile: String?
}

/// URLSession client for the podflow fly.io backend.
/// Auth: shared workspace key in the X-Workspace-Key header.
struct BackendClient: BackendClientProtocol {
    let baseURL: String
    let workspaceKey: String
    let session: URLSession

    init(baseURL: String, workspaceKey: String, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.workspaceKey = workspaceKey
        self.session = session
    }

    private func request(path: String, method: String = "GET", body: Data? = nil) throws -> URLRequest {
        guard !baseURL.isEmpty, !workspaceKey.isEmpty else { throw BackendError.notConfigured }
        let trimmed = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        guard let url = URL(string: trimmed + path) else { throw BackendError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        request.setValue(workspaceKey, forHTTPHeaderField: "X-Workspace-Key")
        if body != nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        request.timeoutInterval = 10
        return request
    }

    private func send(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw BackendError.http(0) }
        switch http.statusCode {
        case 200..<300: return data
        case 401: throw BackendError.unauthorized
        case 404: throw BackendError.notFound
        default: throw BackendError.http(http.statusCode)
        }
    }

    func listEpisodes() async throws -> [BackendEpisode] {
        let data = try await send(request(path: "/episodes"))
        return try JSONDecoder().decode([BackendEpisode].self, from: data)
    }

    func getEpisode(id: String) async throws -> BackendEpisode {
        let encoded = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id
        let data = try await send(request(path: "/episodes/\(encoded)"))
        return try JSONDecoder().decode(BackendEpisode.self, from: data)
    }

    func reportStep(id: String, step: String, status: StepState, metadata: BackendMetadata) async throws {
        struct Payload: Codable {
            var step: String
            var status: String
            var metadata: BackendMetadata
        }
        let encoded = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id
        let body = try JSONEncoder().encode(Payload(step: step, status: status.rawValue, metadata: metadata))
        _ = try await send(request(path: "/episodes/\(encoded)/steps", method: "POST", body: body))
    }

    func putMetadata(id: String, metadata: BackendMetadata) async throws {
        let encoded = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id
        let body = try JSONEncoder().encode(metadata)
        _ = try await send(request(path: "/episodes/\(encoded)/metadata", method: "POST", body: body))
    }

    /// Already gone counts as success.
    func deleteEpisode(id: String) async throws {
        let encoded = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id
        do {
            _ = try await send(request(path: "/episodes/\(encoded)", method: "DELETE"))
        } catch BackendError.notFound {
            return
        }
    }

    func putContent(id: String, key: String, body: String) async throws {
        struct Payload: Codable {
            var key: String
            var body: String
        }
        let encoded = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id
        let data = try JSONEncoder().encode(Payload(key: key, body: body))
        _ = try await send(request(path: "/episodes/\(encoded)/content", method: "POST", body: data))
    }
}
