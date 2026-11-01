import Foundation
import Combine

/// App settings persisted in UserDefaults; the workspace key lives in the
/// Keychain (KeychainStore), never in defaults.
@MainActor
final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    private let defaults: UserDefaults
    private let keychain: KeychainStoring

    init(defaults: UserDefaults = .standard, keychain: KeychainStoring = KeychainStore()) {
        self.defaults = defaults
        self.keychain = keychain
        backendURL = defaults.string(forKey: Keys.backendURL) ?? ""
        storageRootPath = defaults.string(forKey: Keys.storageRoot) ?? ""
        onboardingCompleted = defaults.bool(forKey: Keys.onboardingCompleted)
        let storedCommand = defaults.string(forKey: Keys.transcriptionCommand)
        // Migrate the broken legacy default (parakeet is not an Ollama model).
        if storedCommand == nil || storedCommand == Self.legacyTranscriptionCommand {
            transcriptionCommand = Self.defaultTranscriptionCommand
        } else {
            transcriptionCommand = storedCommand!
        }
        generationModel = defaults.string(forKey: Keys.generationModel) ?? Self.defaultGenerationModel
        generationEngine = GenerationEngine(
            rawValue: defaults.string(forKey: Keys.generationEngine) ?? "") ?? .ollama
        audioServerURLTemplate = defaults.string(forKey: Keys.audioServerURL) ?? ""
        workspaceKey = (try? keychain.read(account: Keys.workspaceKeyAccount)) ?? ""
    }

    enum Keys {
        static let backendURL = "backendURL"
        static let storageRoot = "storageRootPath"
        static let onboardingCompleted = "onboardingCompleted"
        static let transcriptionCommand = "transcriptionCommand"
        static let generationModel = "generationModel"
        static let generationEngine = "generationEngine"
        static let audioServerURL = "audioServerURLTemplate"
        static let workspaceKeyAccount = "podflow-workspace-key"
    }

    static let defaultTranscriptionCommand = "quicksubs {{audio}} --engine parakeet -o {{outputDir}}"
    static let legacyTranscriptionCommand = "quicksubs --model parakeet --output {{output}} {{audio}}"
    static let defaultGenerationModel = "qwen2.5:14b-instruct"
    static let fallbackGenerationModel = "qwen2.5:7b-instruct"

    /// Which engine produces shownotes/social/SEO text.
    enum GenerationEngine: String, CaseIterable, Identifiable {
        case ollama
        case claude

        var id: String { rawValue }
        var label: String {
            switch self {
            case .ollama: return "Ollama (lokal)"
            case .claude: return "Claude Code"
            }
        }
    }

    @Published var backendURL: String {
        didSet { defaults.set(backendURL, forKey: Keys.backendURL) }
    }

    @Published var workspaceKey: String {
        didSet { try? keychain.write(account: Keys.workspaceKeyAccount, value: workspaceKey) }
    }

    @Published var storageRootPath: String {
        didSet { defaults.set(storageRootPath, forKey: Keys.storageRoot) }
    }

    @Published var onboardingCompleted: Bool {
        didSet { defaults.set(onboardingCompleted, forKey: Keys.onboardingCompleted) }
    }

    @Published var transcriptionCommand: String {
        didSet { defaults.set(transcriptionCommand, forKey: Keys.transcriptionCommand) }
    }

    @Published var generationModel: String {
        didSet { defaults.set(generationModel, forKey: Keys.generationModel) }
    }

    @Published var generationEngine: GenerationEngine {
        didSet { defaults.set(generationEngine.rawValue, forKey: Keys.generationEngine) }
    }

    /// URL template for Auphonic-produced audio on the podcast server, e.g.
    /// "https://server/podcast/{{episodeNumber}}_{{slug}}.mp3".
    @Published var audioServerURLTemplate: String {
        didSet { defaults.set(audioServerURLTemplate, forKey: Keys.audioServerURL) }
    }

    var storageRootURL: URL? {
        guard !storageRootPath.isEmpty else { return nil }
        return URL(fileURLWithPath: storageRootPath, isDirectory: true)
    }

    var isBackendConfigured: Bool {
        !backendURL.isEmpty && !workspaceKey.isEmpty
    }
}
