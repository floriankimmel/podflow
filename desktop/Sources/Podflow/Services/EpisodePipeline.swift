import Foundation

/// Runs an episode through the plugin: `prepare` up to the review, `publish`
/// after it. Hides the settings check, the CLI config, the run environment,
/// the headless Claude run and the outcome check behind two calls that return
/// the episode's new state or throw a user-facing error.
struct EpisodePipeline {
    /// Snapshot of the settings a run needs.
    struct Settings: Sendable {
        /// Secrets and run settings as environment variables.
        var environment: [String: String]
        /// User-facing names of required settings that are still empty.
        var missing: [String]
        var wordpressServer: String
        var ftpHost: String
        var ftpPort: String
        var coverBaseURL: String
    }

    /// What the review step decides before publishing.
    struct Review: Sendable {
        var releaseDate: Date
        var coverFile: String
        var featuredFile: String
    }

    enum PipelineError: LocalizedError, Equatable {
        case notOnThisMac
        case missingSettings([String])
        case stepFailed(label: String, detail: String)
        case runFailed(String)

        var errorDescription: String? {
            switch self {
            case .notOnThisMac:
                return "Diese Episode liegt nicht auf diesem Mac."
            case .missingSettings(let names):
                return "In den Einstellungen fehlt noch: \(names.joined(separator: ", "))."
            case .stepFailed(let label, let detail):
                return detail.isEmpty ? "„\(label)“ ist fehlgeschlagen." : "„\(label)“ ist fehlgeschlagen: \(detail)"
            case .runFailed(let detail):
                return detail.isEmpty ? "Der Lauf wurde mit einem Fehler beendet." : detail
            }
        }
    }

    let store: EpisodeStore
    let runner: ClaudeRunner
    let publishConfig: PublishConfig

    init(store: EpisodeStore = EpisodeStore(), runner: ClaudeRunner = ClaudeRunner(), publishConfig: PublishConfig = PublishConfig()) {
        self.store = store
        self.runner = runner
        self.publishConfig = publishConfig
    }

    /// Auphonic, transcript, generation and fact-check. Resumes after a failure.
    func prepare(
        _ episode: Episode,
        settings: Settings,
        onLog: @escaping @Sendable (String) -> Void
    ) async throws -> EpisodeState {
        let (folder, _) = try local(episode, settings: settings)
        return try await run(.prepare, folder: folder, environment: settings.environment, onLog: onLog)
    }

    /// YouTube and audio via Auphonic, then WordPress via the CLI. Resumes after a failure.
    func publish(
        _ episode: Episode,
        review: Review,
        settings: Settings,
        onLog: @escaping @Sendable (String) -> Void
    ) async throws -> EpisodeState {
        let (folder, state) = try local(episode, settings: settings)
        let configFile = try publishConfig.write(
            PublishConfig.Inputs(
                number: state.number,
                title: state.title,
                audioBasename: state.audioBasename,
                releaseDate: review.releaseDate,
                coverFile: review.coverFile,
                featuredFile: review.featuredFile,
                wordpressServer: settings.wordpressServer,
                ftpHost: settings.ftpHost,
                ftpPort: settings.ftpPort,
                coverBaseURL: settings.coverBaseURL
            ),
            episodeFolder: folder
        )
        var environment = settings.environment
        environment[EnvName.configFile] = configFile
        return try await run(.publish, folder: folder, environment: environment, onLog: onLog)
    }

    private func local(_ episode: Episode, settings: Settings) throws -> (URL, EpisodeState) {
        guard let folder = episode.folderURL, let state = store.readState(in: folder) else {
            throw PipelineError.notOnThisMac
        }
        guard settings.missing.isEmpty else { throw PipelineError.missingSettings(settings.missing) }
        return (folder, state)
    }

    private func run(
        _ mode: RunMode,
        folder: URL,
        environment: [String: String],
        onLog: @escaping @Sendable (String) -> Void
    ) async throws -> EpisodeState {
        let outcome = try await runner.run(mode: mode, episodeFolder: folder, environment: environment, onLog: onLog)
        guard let state = store.readState(in: folder) else { throw PipelineError.notOnThisMac }
        // A failed step is the precise error; the run's own result is the fallback.
        if let failed = state.failedStep {
            throw PipelineError.stepFailed(label: PipelineStage.label(for: failed.id), detail: failed.error)
        }
        if outcome.isError { throw PipelineError.runFailed(outcome.summary) }
        // A run can end cleanly without getting there (the skill refused, or
        // Claude stopped early); that is not a success.
        guard Self.reachedGoal(mode, state) else {
            let goal = PipelineStage.label(for: mode == .prepare ? StepID.review : StepID.scheduled)
            let detail = outcome.summary.isEmpty ? "" : " \(outcome.summary)"
            throw PipelineError.runFailed("Der Lauf hat „\(goal)“ nicht erreicht.\(detail)")
        }
        return state
    }

    private static func reachedGoal(_ mode: RunMode, _ state: EpisodeState) -> Bool {
        switch mode {
        case .prepare: return [.inProgress, .done].contains(state.status(of: StepID.review))
        case .publish: return state.status(of: StepID.scheduled) == .done
        }
    }
}
