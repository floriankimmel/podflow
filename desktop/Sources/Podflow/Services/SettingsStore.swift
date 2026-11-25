import Foundation
import Combine

/// App settings. Secrets live in the Keychain, everything else in UserDefaults.
/// Secrets reach the plugin and the CLI only as environment variables of a run.
@MainActor
final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    private let defaults: UserDefaults
    private let keychain: KeychainStoring

    enum Keys {
        static let backendURL = "backendURL"
        static let onboardingCompleted = "onboardingCompleted"
        static let auphonicPreset = "auphonicPreset"
        static let wordpressServer = "wordpressServer"
        static let ftpHost = "ftpHost"
        static let ftpPort = "ftpPort"
        /// Stored under the old name so existing settings survive the rename.
        static let coverBaseURL = "posterBaseURL"
        static let releaseTime = "releaseTime"
        static let episodesFolder = "episodesFolder"
    }

    /// Keychain accounts; raw value doubles as the environment variable name.
    enum Secret: String, CaseIterable {
        case workspaceKey = "PODFLOW_WORKSPACE_KEY"
        case auphonicUser = "AUPHONIC_USER"
        case auphonicPassword = "AUPHONIC_PWD"
        case wordpressKey = "WP_KEY"
        case ftpUser = "FTP_USER"
        case ftpPassword = "FTP_PWD"
    }

    static let defaultBackendURL = "https://podflow-backend.fly.dev"
    static let defaultWordpressServer = "https://laufendentdecken-podcast.at"
    static let defaultFTPHost = "rssfeed.laufendentdecken-podcast.at"
    static let defaultCoverBaseURL = "http://rssfeed.laufendentdecken-podcast.at/data/"

    init(defaults: UserDefaults = .standard, keychain: KeychainStoring = KeychainStore()) {
        self.defaults = defaults
        self.keychain = keychain
        backendURL = defaults.string(forKey: Keys.backendURL) ?? Self.defaultBackendURL
        onboardingCompleted = defaults.bool(forKey: Keys.onboardingCompleted)
        auphonicPreset = defaults.string(forKey: Keys.auphonicPreset) ?? ""
        wordpressServer = defaults.string(forKey: Keys.wordpressServer) ?? Self.defaultWordpressServer
        ftpHost = defaults.string(forKey: Keys.ftpHost) ?? Self.defaultFTPHost
        ftpPort = defaults.string(forKey: Keys.ftpPort) ?? "21"
        coverBaseURL = defaults.string(forKey: Keys.coverBaseURL) ?? Self.defaultCoverBaseURL
        releaseTime = defaults.string(forKey: Keys.releaseTime) ?? "09:00"
        episodesFolder = defaults.string(forKey: Keys.episodesFolder) ?? EpisodeStore.defaultRoot.path
        var loaded: [Secret: String] = [:]
        for secret in Secret.allCases {
            loaded[secret] = (try? keychain.read(account: secret.rawValue)) ?? ""
        }
        secrets = loaded
    }

    @Published var backendURL: String {
        didSet { defaults.set(backendURL, forKey: Keys.backendURL) }
    }

    @Published var onboardingCompleted: Bool {
        didSet { defaults.set(onboardingCompleted, forKey: Keys.onboardingCompleted) }
    }

    @Published var auphonicPreset: String {
        didSet { defaults.set(auphonicPreset, forKey: Keys.auphonicPreset) }
    }

    @Published var wordpressServer: String {
        didSet { defaults.set(wordpressServer, forKey: Keys.wordpressServer) }
    }

    @Published var ftpHost: String {
        didSet { defaults.set(ftpHost, forKey: Keys.ftpHost) }
    }

    @Published var ftpPort: String {
        didSet { defaults.set(ftpPort, forKey: Keys.ftpPort) }
    }

    /// Public URL prefix of the files uploaded by FTP (podcast cover).
    @Published var coverBaseURL: String {
        didSet { defaults.set(coverBaseURL, forKey: Keys.coverBaseURL) }
    }

    /// Default release time of day ("HH:mm") suggested in the review step.
    @Published var releaseTime: String {
        didSet { defaults.set(releaseTime, forKey: Keys.releaseTime) }
    }

    /// Folder holding one subfolder per episode.
    @Published var episodesFolder: String {
        didSet { defaults.set(episodesFolder, forKey: Keys.episodesFolder) }
    }

    var episodesFolderURL: URL {
        URL(fileURLWithPath: (episodesFolder as NSString).expandingTildeInPath, isDirectory: true)
    }

    @Published private(set) var secrets: [Secret: String]

    func secret(_ secret: Secret) -> String {
        secrets[secret] ?? ""
    }

    func setSecret(_ secret: Secret, _ value: String) {
        secrets[secret] = value
        try? keychain.write(account: secret.rawValue, value: value)
    }

    var workspaceKey: String { secret(.workspaceKey) }

    var isBackendConfigured: Bool {
        !backendURL.isEmpty && !workspaceKey.isEmpty
    }

    /// Settings a run cannot work without, as user-facing names.
    var missingForRun: [String] {
        var missing: [String] = []
        if secret(.auphonicUser).isEmpty || secret(.auphonicPassword).isEmpty { missing.append("Auphonic-Zugang") }
        if auphonicPreset.isEmpty { missing.append("Auphonic-Preset") }
        if secret(.wordpressKey).isEmpty { missing.append("WordPress-Schlüssel") }
        if secret(.ftpUser).isEmpty || secret(.ftpPassword).isEmpty { missing.append("FTP-Zugang") }
        return missing
    }

    /// Everything a pipeline run needs from the settings.
    var pipelineSettings: EpisodePipeline.Settings {
        EpisodePipeline.Settings(
            environment: runEnvironment(),
            missing: missingForRun,
            wordpressServer: wordpressServer,
            ftpHost: ftpHost,
            ftpPort: ftpPort,
            coverBaseURL: coverBaseURL
        )
    }

    /// Environment for a headless run: secrets plus non-secret run settings.
    func runEnvironment() -> [String: String] {
        var environment: [String: String] = [:]
        for secret in Secret.allCases where !self.secret(secret).isEmpty {
            environment[secret.rawValue] = self.secret(secret)
        }
        environment[EnvName.auphonicPreset] = auphonicPreset
        if !backendURL.isEmpty { environment[EnvName.backendURL] = backendURL }
        return environment
    }
}
