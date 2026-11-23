import Combine
import Foundation
import SwiftUI

/// Central view model: local episode folders merged with the shared backend
/// status, and the headless Claude runs (prepare / publish) for an episode.
@MainActor
final class AppModel: ObservableObject {
    enum ConnectionState: Equatable {
        case unconfigured
        case connected
        case authError
        case offline
    }

    struct ActiveRun: Equatable {
        var episodeID: String
        var mode: RunMode
    }

    @Published var episodes: [Episode] = []
    @Published var selectedEpisodeID: String?
    @Published var connection: ConnectionState = .unconfigured
    @Published var activeRun: ActiveRun?
    @Published var runLog: [String] = []
    @Published var lastError: String?
    @Published var claudeStatus: ClaudeSetup.Status?

    let settings: SettingsStore
    let setup: ClaudeSetup
    /// Rebuilt when the episodes folder changes in the settings.
    private(set) var store: EpisodeStore
    private(set) var pipeline: EpisodePipeline

    private var pollTask: Task<Void, Never>?
    private var folderObserver: AnyCancellable?

    init(settings: SettingsStore, setup: ClaudeSetup = ClaudeSetup()) {
        self.settings = settings
        self.setup = setup
        let store = EpisodeStore(root: settings.episodesFolderURL)
        self.store = store
        self.pipeline = EpisodePipeline(store: store, runner: ClaudeRunner(setup: setup))
        folderObserver = settings.$episodesFolder
            .dropFirst()
            .removeDuplicates()
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.useEpisodesFolder(self.settings.episodesFolderURL)
            }
    }

    private func useEpisodesFolder(_ root: URL) {
        store = EpisodeStore(root: root)
        pipeline = EpisodePipeline(store: store, runner: ClaudeRunner(setup: setup))
        selectedEpisodeID = nil
        Task { await refresh() }
    }

    var backendClient: BackendClient? {
        guard settings.isBackendConfigured else { return nil }
        return BackendClient(baseURL: settings.backendURL, workspaceKey: settings.workspaceKey)
    }

    var selectedEpisode: Episode? {
        episodes.first { $0.id == selectedEpisodeID }
    }

    func isRunning(_ episode: Episode) -> Bool {
        activeRun?.episodeID == episode.id
    }

    var nextEpisodeNumber: String {
        EpisodeStore.nextNumber(known: episodes.map(\.number))
    }

    // MARK: Refresh

    func refresh() async {
        var merged: [String: Episode] = [:]
        for episode in store.listEpisodes() {
            merged[episode.id] = episode
        }

        if let client = backendClient {
            do {
                for record in try await client.listEpisodes() {
                    let id = record.episodeNumber ?? record.id
                    var episode = merged[id] ?? Episode(id: id)
                    episode.backendTitle = record.title
                    episode.backendSteps = record.steps
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

        episodes = merged.values.sorted { lhs, rhs in
            let l = Int(lhs.number) ?? -1
            let r = Int(rhs.number) ?? -1
            if l != r { return l > r }
            return lhs.id.localizedStandardCompare(rhs.id) == .orderedDescending
        }
    }

    /// Re-reads `state.json` of the local episodes (cheap; used while a run is active).
    func reloadLocalState() {
        for index in episodes.indices {
            guard let folder = episodes[index].folderURL, let state = store.readState(in: folder) else { continue }
            if episodes[index].state != state { episodes[index].state = state }
        }
    }

    func refreshClaudeStatus() async {
        claudeStatus = await setup.status()
    }

    // MARK: Episodes

    func createEpisode(number: String, title: String, type: EpisodeType, video: URL?, transcript: URL?) async throws {
        try store.create(number: number, title: title, type: type, video: video, transcript: transcript)
        if let client = backendClient {
            let metadata = BackendMetadata(episodeNumber: number, slug: nil, title: title, releaseDate: nil, profile: "video")
            try? await client.putMetadata(id: number, metadata: metadata)
        }
        await refresh()
        selectedEpisodeID = number
    }

    /// Removes the episode from the shared status (for both hosts) and, when
    /// it is on this Mac, moves its folder to the Trash. Nothing is removed
    /// from Auphonic, YouTube or WordPress.
    func deleteEpisode(_ episode: Episode) async {
        guard !isRunning(episode) else { return }
        lastError = nil
        do {
            if let client = backendClient {
                try await client.deleteEpisode(id: episode.id)
            }
            if episode.isLocal {
                try store.delete(number: episode.number)
                PublishConfig().remove(number: episode.number)
            }
            if selectedEpisodeID == episode.id { selectedEpisodeID = nil }
        } catch {
            lastError = "Episode konnte nicht gelöscht werden: \(error.localizedDescription)"
        }
        await refresh()
    }

    // MARK: Runs

    func startPrepare(_ episode: Episode) async {
        await track(.prepare, episode) { [pipeline, settings = settings.pipelineSettings] onLog in
            try await pipeline.prepare(episode, settings: settings, onLog: onLog)
        }
    }

    func startPublish(_ episode: Episode, review: EpisodePipeline.Review) async {
        await track(.publish, episode) { [pipeline, settings = settings.pipelineSettings] onLog in
            try await pipeline.publish(episode, review: review, settings: settings, onLog: onLog)
        }
    }

    /// UI bookkeeping around one pipeline run: one run at a time, live log,
    /// live step status, error banner.
    private func track(
        _ mode: RunMode,
        _ episode: Episode,
        _ work: @escaping (@escaping @Sendable (String) -> Void) async throws -> EpisodeState
    ) async {
        guard activeRun == nil else { return }
        activeRun = ActiveRun(episodeID: episode.id, mode: mode)
        runLog = []
        lastError = nil
        startPolling()
        do {
            _ = try await work { [weak self] line in
                Task { @MainActor in self?.appendLog(line) }
            }
        } catch {
            lastError = error.localizedDescription
        }
        stopPolling()
        activeRun = nil
        await refresh()
    }

    private func appendLog(_ line: String) {
        runLog.append(line)
        if runLog.count > 500 { runLog.removeFirst(runLog.count - 500) }
    }

    private func startPolling() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                self?.reloadLocalState()
            }
        }
    }

    private func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }
}
