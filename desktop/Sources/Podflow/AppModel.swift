import Foundation
import SwiftUI

/// Central view model: merges local episode folders with backend records,
/// drives adaptive polling (D4: on-demand when idle, 5s while any step of the
/// viewed episode is in progress), and runs the pipeline actions.
@MainActor
final class AppModel: ObservableObject {
    enum ConnectionState: Equatable {
        case unconfigured
        case connected
        case authError
        case offline
    }

    @Published var episodes: [Episode] = []
    @Published var backendRecords: [String: BackendEpisode] = [:]
    @Published var selectedEpisodeID: String?
    @Published var connection: ConnectionState = .unconfigured
    @Published var lastRefreshed: Date?
    @Published var runningAction: String?
    @Published var actionLog: String = ""
    @Published var lastError: String?
    @Published var showPatreonReminder = false

    let settings: SettingsStore
    let presets: PresetStore
    let discovery = EpisodeDiscovery()
    let runner = PodflowRunner()
    let readiness = ReadinessCheck()
    let promptStore = PromptStore()

    private var pollTask: Task<Void, Never>?

    init(settings: SettingsStore, presets: PresetStore) {
        self.settings = settings
        self.presets = presets
    }

    var backendClient: BackendClient? {
        guard settings.isBackendConfigured else { return nil }
        return BackendClient(baseURL: settings.backendURL, workspaceKey: settings.workspaceKey)
    }

    var selectedEpisode: Episode? {
        episodes.first { $0.id == selectedEpisodeID }
    }

    func backendRecord(for episode: Episode) -> BackendEpisode? {
        backendRecords[episode.id]
    }

    // MARK: Refresh / merge

    func refresh() async {
        var merged: [String: Episode] = [:]

        // Local folders
        if let root = settings.storageRootURL {
            for local in discovery.listEpisodes(root: root) {
                let identity = local.identity
                merged[identity] = Episode(
                    id: identity,
                    local: local,
                    backendID: nil,
                    episodeNumber: local.episodeNumber,
                    title: local.title,
                    releaseDate: local.releaseDate,
                    profileID: local.profileID
                )
            }
        }

        // Backend records
        if let client = backendClient {
            do {
                let records = try await client.listEpisodes()
                connection = .connected
                var recordMap: [String: BackendEpisode] = [:]
                for record in records {
                    recordMap[record.id] = record
                    if var existing = merged[record.id] {
                        existing.backendID = record.id
                        existing.episodeNumber = existing.episodeNumber ?? record.episodeNumber
                        if (existing.title ?? "").isEmpty { existing.title = record.title }
                        existing.releaseDate = existing.releaseDate ?? record.releaseDate
                        existing.profileID = existing.profileID ?? record.profile
                        merged[record.id] = existing
                    } else {
                        merged[record.id] = Episode(
                            id: record.id,
                            local: nil,
                            backendID: record.id,
                            episodeNumber: record.episodeNumber,
                            title: record.title,
                            releaseDate: record.releaseDate,
                            profileID: record.profile
                        )
                    }
                }
                backendRecords = recordMap
            } catch BackendError.unauthorized {
                connection = .authError
            } catch {
                connection = .offline
            }
        } else {
            connection = .unconfigured
        }

        episodes = merged.values.sorted { lhs, rhs in
            let l = Int(lhs.episodeNumber ?? "") ?? -1
            let r = Int(rhs.episodeNumber ?? "") ?? -1
            if l != r { return l > r }
            return lhs.id.localizedStandardCompare(rhs.id) == .orderedDescending
        }
        lastRefreshed = Date()
        updatePolling()
    }

    func refreshSelected() async {
        guard let episode = selectedEpisode, let client = backendClient else { return }
        if let record = try? await client.getEpisode(id: episode.id) {
            backendRecords[episode.id] = record
            lastRefreshed = Date()
        }
        updatePolling()
    }

    /// Adaptive polling (D4): a 5s loop only while a step of the selected
    /// episode is in progress or an app action is running.
    func updatePolling() {
        let active = runningAction != nil
            || (selectedEpisode.flatMap { backendRecords[$0.id]?.anyStepInProgress } ?? false)
        if active, pollTask == nil {
            pollTask = Task { [weak self] in
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(5))
                    await self?.refreshSelected()
                    guard let self, self.pollTask != nil else { return }
                }
            }
        } else if !active {
            pollTask?.cancel()
            pollTask = nil
        }
    }

    // MARK: Step reporting

    func report(episode: Episode, step: String, status: StepState) async {
        guard let client = backendClient else { return }
        let metadata = BackendMetadata(
            episodeNumber: episode.episodeNumber,
            slug: episode.local?.slug,
            title: episode.title,
            releaseDate: episode.releaseDate,
            profile: episode.profileID
        )
        try? await client.reportStep(id: episode.id, step: step, status: status, metadata: metadata)
        await refreshSelected()
    }

    func pushContent(episode: Episode, key: String, body: String) async {
        guard let client = backendClient else { return }
        try? await client.putContent(id: episode.id, key: key, body: body)
    }

    // MARK: Pipeline actions

    private func appliedConfig(for episode: Episode) throws -> PodflowConfig? {
        let presetID = episode.local.flatMap { local in
            discovery.readAppMetadata(from: local.folderURL).presetID.flatMap(UUID.init(uuidString:))
        }
        guard let preset = presets.preset(id: presetID) ?? presets.defaultPreset else { return nil }
        try presets.validate(preset)
        let missing = presets.missingEnvVariables(for: preset)
        if !missing.isEmpty {
            throw PresetError.missingEnvVariables(missing)
        }
        return preset.configuration.removingPublishSteps(episode.profile.excludedPublishSteps)
    }

    func runPublish(for episode: Episode) async {
        guard let folder = episode.local?.folderURL else { return }
        runningAction = "publish"
        actionLog = ""
        lastError = nil
        updatePolling()
        defer {
            runningAction = nil
            updatePolling()
        }
        do {
            let config = try appliedConfig(for: episode)
            let result = try await runner.run(
                command: ["publish"],
                episodeFolder: folder,
                configuration: config,
                backendURL: settings.backendURL,
                workspaceKey: settings.workspaceKey,
                onOutput: { text in
                    Task { @MainActor [weak self] in self?.actionLog += text }
                }
            )
            if result.exitCode == 0 {
                // Manual follow-up: Patreon upload reminder (task 9.2).
                showPatreonReminder = true
            } else {
                lastError = "podflow publish beendet mit Exit-Code \(result.exitCode)"
            }
        } catch {
            lastError = error.localizedDescription
        }
        await refresh()
    }

    func runTranscription(for episode: Episode, force: Bool = false) async {
        guard let folder = episode.local?.folderURL else { return }
        runningAction = "transcribe"
        lastError = nil
        updatePolling()
        defer {
            runningAction = nil
            updatePolling()
        }
        await report(episode: episode, step: "transcribe", status: .inProgress)
        do {
            let service = TranscriptionService(commandTemplate: settings.transcriptionCommand)
            let transcript = try await service.transcribe(episodeFolder: folder, force: force)
            await pushContent(episode: episode, key: ContentKey.transcript, body: transcript)
            await report(episode: episode, step: "transcribe", status: .done)
        } catch {
            lastError = error.localizedDescription
            await report(episode: episode, step: "transcribe", status: .failed)
        }
    }

    private func generationService() -> GenerationService {
        let runner: TextModelRunner
        switch settings.generationEngine {
        case .claude:
            runner = ClaudeCodeModelRunner()
        case .ollama:
            runner = OllamaModelRunner(ollama: OllamaClient(), model: settings.generationModel)
        }
        return GenerationService(runner: runner, prompts: promptStore)
    }

    func runGeneration(_ step: String, for episode: Episode, force: Bool = false) async {
        guard let folder = episode.local?.folderURL else { return }
        runningAction = step
        lastError = nil
        updatePolling()
        defer {
            runningAction = nil
            updatePolling()
        }
        await report(episode: episode, step: step, status: .inProgress)
        do {
            let service = generationService()
            let config = try? appliedConfig(for: episode)
            switch step {
            case "shownotes":
                let text = try await service.generateShownotes(
                    episodeFolder: folder, episodeNumber: episode.episodeNumber, config: config, force: force)
                await pushContent(episode: episode, key: ContentKey.shownotes, body: text)
            case "social":
                let posts = try await service.generateSocial(
                    episodeFolder: folder, episodeNumber: episode.episodeNumber, config: config, force: force)
                for (platform, post) in posts {
                    await pushContent(episode: episode, key: ContentKey.social(platform), body: post)
                }
            case "seo":
                let text = try await service.generateSEO(
                    episodeFolder: folder, episodeNumber: episode.episodeNumber, config: config, force: force)
                await pushContent(episode: episode, key: ContentKey.seo, body: text)
            default:
                break
            }
            await report(episode: episode, step: step, status: .done)
        } catch {
            lastError = error.localizedDescription
            await report(episode: episode, step: step, status: .failed)
        }
    }
}
