import Foundation

/// The episodes of both hosts: local episode folders merged with the shared
/// backend status, and creating and deleting an episode across folder,
/// backend and CLI config.
@MainActor
struct EpisodeCatalog {
    enum Connection: Equatable {
        case unconfigured
        case connected
        case authError
        case offline
    }

    struct Listing: Equatable {
        var episodes: [Episode]
        var connection: Connection
    }

    let store: EpisodeStore
    /// The backend as currently configured, nil when it is not set up.
    let backend: () -> BackendClientProtocol?

    /// Local episodes keep their `state.json`; the backend adds title and step
    /// status, and contributes the other host's episodes ("not on this Mac").
    /// Newest number first. Backend problems never hide local episodes.
    func list() async -> Listing {
        var merged: [String: Episode] = [:]
        for episode in store.listEpisodes() {
            merged[episode.id] = episode
        }

        let connection: Connection
        if let client = backend() {
            do {
                for record in try await client.listEpisodes() {
                    let id = record.episodeNumber ?? record.id
                    var episode = merged[id] ?? Episode(id: id)
                    episode.backendTitle = record.title
                    episode.backendSteps = record.steps
                    if episode.releaseDate == nil, let date = record.releaseDate {
                        episode.releaseDate = ISO8601DateFormatter().date(from: date)
                    }
                    merged[id] = episode
                }
                connection = .connected
            } catch BackendError.unauthorized {
                connection = .authError
            } catch {
                connection = .offline
            }
        } else {
            connection = .unconfigured
        }

        let episodes = merged.values.sorted { lhs, rhs in
            let l = Int(lhs.number) ?? -1
            let r = Int(rhs.number) ?? -1
            if l != r { return l > r }
            return lhs.id.localizedStandardCompare(rhs.id) == .orderedDescending
        }
        return Listing(episodes: episodes, connection: connection)
    }

    /// Creates the folder, then announces the episode to the backend (best
    /// effort: the first step report would add it anyway).
    func create(number: String, title: String, type: EpisodeType, video: URL?, transcript: URL?) async throws {
        try store.create(number: number, title: title, type: type, video: video, transcript: transcript)
        if let client = backend() {
            let metadata = BackendMetadata(
                episodeNumber: number, title: title, releaseDate: nil, profile: BackendProfile.video)
            try? await client.putMetadata(number: number, metadata: metadata)
        }
    }

    /// Shares the release date of a published episode, so the other host sees
    /// when it goes live. Best effort.
    func announceRelease(number: String, releaseDate: Date) async {
        guard let client = backend() else { return }
        let metadata = BackendMetadata(
            episodeNumber: number, title: nil,
            releaseDate: ISO8601DateFormatter().string(from: releaseDate), profile: nil)
        try? await client.putMetadata(number: number, metadata: metadata)
    }

    /// Removes the episode from the shared status first, then, when it is on
    /// this Mac, moves its folder to the Trash. A
    /// backend failure stops before anything local is touched. Nothing is
    /// removed from Auphonic, YouTube or WordPress.
    func delete(_ episode: Episode) async throws {
        if let client = backend() {
            try await client.deleteEpisode(number: episode.id)
        }
        if episode.isLocal {
            try store.delete(number: episode.number)
        }
    }
}
