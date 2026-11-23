import Combine
import Foundation
import SwiftUI

/// Central view model: local episode folders merged with the shared backend
/// status, and the headless Claude runs (prepare / publish) for an episode.
@MainActor
final class AppModel: ObservableObject {
    typealias ConnectionState = EpisodeCatalog.Connection

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
    private(set) var catalog: EpisodeCatalog
    private let publishConfig: PublishConfig

    private var pollTask: Task<Void, Never>?
    private var folderObserver: AnyCancellable?

    init(
        settings: SettingsStore,
        setup: ClaudeSetup = ClaudeSetup(),
        publishConfig: PublishConfig = PublishConfig(),
        backend: (() -> BackendClientProtocol?)? = nil
    ) {
        self.settings = settings
        self.setup = setup
        self.publishConfig = publishConfig
        let backend = backend ?? { [settings] in
            guard settings.isBackendConfigured else { return nil }
            return BackendClient(baseURL: settings.backendURL, workspaceKey: settings.workspaceKey)
        }
        self.backend = backend
        let store = EpisodeStore(root: settings.episodesFolderURL)
        self.store = store
        self.pipeline = EpisodePipeline(store: store, runner: ClaudeRunner(setup: setup), publishConfig: publishConfig)
        self.catalog = EpisodeCatalog(store: store, publishConfig: publishConfig, backend: backend)
        folderObserver = settings.$episodesFolder
            .dropFirst()
            .removeDuplicates()
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.useEpisodesFolder(self.settings.episodesFolderURL)
            }
    }

    private let backend: () -> BackendClientProtocol?

    private func useEpisodesFolder(_ root: URL) {
        store = EpisodeStore(root: root)
        pipeline = EpisodePipeline(store: store, runner: ClaudeRunner(setup: setup), publishConfig: publishConfig)
        catalog = EpisodeCatalog(store: store, publishConfig: publishConfig, backend: backend)
        selectedEpisodeID = nil
        Task { await refresh() }
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
        let listing = await catalog.list()
        episodes = listing.episodes
        connection = listing.connection
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
        try await catalog.create(number: number, title: title, type: type, video: video, transcript: transcript)
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
            try await catalog.delete(episode)
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
