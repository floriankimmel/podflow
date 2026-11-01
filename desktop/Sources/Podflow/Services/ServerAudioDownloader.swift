import Foundation

/// Stateful download of the Auphonic-produced audio from the podcast server
/// into the episode folder (auphonic-video-ingest D5/D6). Polls until the file
/// is available; reports "awaiting produced audio" until then.
struct ServerAudioDownloader: Sendable {
    var session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    enum DownloadState: Equatable, Sendable {
        case awaitingProducedAudio
        case downloaded(URL)
    }

    enum DownloadError: LocalizedError {
        case invalidURL(String)

        var errorDescription: String? {
            switch self {
            case .invalidURL(let template):
                return "Ungültige Audio-Server-URL: \(template)"
            }
        }
    }

    /// Resolves the audio URL template ({{episodeNumber}}, {{slug}}).
    static func resolveURL(template: String, episodeNumber: String?, slug: String) -> URL? {
        var text = template.replacingOccurrences(of: "{{episodeNumber}}", with: episodeNumber ?? "")
        text = text.replacingOccurrences(of: "{{slug}}", with: slug)
        return URL(string: text)
    }

    /// One poll attempt: downloads when available, otherwise reports waiting.
    func attemptDownload(template: String, episodeFolder: URL, episodeNumber: String?) async throws -> DownloadState {
        let slug = episodeFolder.lastPathComponent
        guard let url = Self.resolveURL(template: template, episodeNumber: episodeNumber, slug: slug) else {
            throw DownloadError.invalidURL(template)
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 60

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            return .awaitingProducedAudio
        }
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            return .awaitingProducedAudio
        }
        guard !data.isEmpty else { return .awaitingProducedAudio }

        let fileName = url.lastPathComponent.isEmpty ? "\(slug).mp3" : url.lastPathComponent
        let destination = episodeFolder.appendingPathComponent(fileName)
        try data.write(to: destination)
        return .downloaded(destination)
    }
}
