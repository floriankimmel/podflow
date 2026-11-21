import Foundation

/// Onboarding dependency detection and guided install (design D9): download or
/// invoke each tool's own installer, never bundle. Re-runnable; publish
/// readiness requires only the podflow CLI + storage root, transcription tools
/// are staged.
@MainActor
final class DependencyManager: ObservableObject {
    enum DependencyID: String, CaseIterable, Identifiable {
        case podflow
        case ollama
        case parakeet
        case generationModel
        case claudeCode
        case pi

        var id: String { rawValue }
    }

    struct Dependency: Identifiable {
        let id: DependencyID
        let name: String
        let detail: String
        let requiredForPublish: Bool
        var state: State = .unknown
        var progress: Double?
        var message: String?

        enum State {
            case unknown
            case checking
            case installed
            case missing
            case installing
            case failed
        }
    }

    @Published var dependencies: [Dependency]
    @Published var isChecking = false

    private let ollama: OllamaClient
    private let settings: SettingsStore

    init(ollama: OllamaClient = OllamaClient(), settings: SettingsStore) {
        self.ollama = ollama
        self.settings = settings
        dependencies = [
            Dependency(id: .podflow, name: "podflow CLI",
                       detail: "Publish-Pipeline (Homebrew oder Release-Binary)",
                       requiredForPublish: true),
            Dependency(id: .ollama, name: "Ollama",
                       detail: "Lokale Modell-Runtime für Transkription & Generierung",
                       requiredForPublish: false),
            Dependency(id: .parakeet, name: "quicksubs (Parakeet ASR)",
                       detail: "Transkriptions-CLI — Parakeet-Modell lädt beim ersten Lauf (~400 MB)",
                       requiredForPublish: false),
            Dependency(id: .generationModel, name: SettingsStore.defaultGenerationModel,
                       detail: "Text-Modell für Shownotes/Social/SEO (Engine: Ollama)",
                       requiredForPublish: false),
            Dependency(id: .claudeCode, name: "Claude Code",
                       detail: "Alternative Generierungs-Engine (claude CLI)",
                       requiredForPublish: false),
            Dependency(id: .pi, name: "pi Coding Agent",
                       detail: "Prompt-Orchestrierung (optional)",
                       requiredForPublish: false),
        ]
    }

    private func index(of id: DependencyID) -> Int? {
        dependencies.firstIndex { $0.id == id }
    }

    private func set(_ id: DependencyID, state: Dependency.State, progress: Double? = nil, message: String? = nil) {
        guard let index = index(of: id) else { return }
        dependencies[index].state = state
        dependencies[index].progress = progress
        dependencies[index].message = message
    }

    /// Publish-ready: podflow CLI installed + storage root set (D9 staging).
    var isReadyForPublish: Bool {
        let podflowInstalled = dependencies.first { $0.id == .podflow }?.state == .installed
        return podflowInstalled && settings.storageRootURL != nil
    }

    var allInstalled: Bool {
        dependencies.allSatisfy { $0.state == .installed }
    }

    // MARK: Detection

    func detectAll() async {
        isChecking = true
        defer { isChecking = false }
        for id in DependencyID.allCases {
            set(id, state: .checking)
            let installed = await detect(id)
            set(id, state: installed ? .installed : .missing)
        }
    }

    func detect(_ id: DependencyID) async -> Bool {
        switch id {
        case .podflow:
            return PodflowRunner.findPodflowBinary() != nil
        case .ollama:
            if binaryExists("ollama") { return true }
            return await ollama.isReachable()
        case .parakeet:
            return binaryExists("quicksubs")
        case .generationModel:
            return await ollama.hasModel(settings.generationModel)
        case .claudeCode:
            return binaryExists("claude")
        case .pi:
            return binaryExists("pi")
        }
    }

    nonisolated private func binaryExists(_ name: String) -> Bool {
        let candidates = ["/opt/homebrew/bin/", "/usr/local/bin/", "/usr/bin/",
                          NSHomeDirectory() + "/.local/bin/", NSHomeDirectory() + "/go/bin/"]
        for dir in candidates where FileManager.default.isExecutableFile(atPath: dir + name) {
            return true
        }
        if let path = ProcessInfo.processInfo.environment["PATH"] {
            for dir in path.split(separator: ":")
            where FileManager.default.isExecutableFile(atPath: String(dir) + "/" + name) {
                return true
            }
        }
        return false
    }

    // MARK: Install

    func install(_ id: DependencyID) async {
        set(id, state: .installing, progress: nil)
        do {
            switch id {
            case .podflow:
                try await runInstaller(["brew", "install", "fkimmel/tap/podflow"],
                                       fallback: ["go", "install", "github.com/floriankimmel/podflow/cmd/podflow@latest"])
            case .ollama:
                try await runInstaller(["brew", "install", "--cask", "ollama"], fallback: nil)
            case .parakeet:
                try await runInstaller(["brew", "install", "mattbirchler/tap/quicksubs"], fallback: nil)
            case .generationModel:
                try await pullModel(settings.generationModel, id: id)
            case .claudeCode:
                try await runInstaller(["brew", "install", "--cask", "claude-code"],
                                       fallback: ["npm", "install", "-g", "@anthropic-ai/claude-code"])
            case .pi:
                try await runInstaller(["brew", "install", "pi-coding-agent"], fallback: nil)
            }
            let installed = await detect(id)
            set(id, state: installed ? .installed : .failed,
                message: installed ? nil : "Installation abgeschlossen, aber Tool nicht gefunden.")
        } catch {
            set(id, state: .failed, message: error.localizedDescription)
        }
    }

    private func pullModel(_ model: String, id: DependencyID) async throws {
        guard await ollama.isReachable() else {
            throw NSError(domain: "Onboarding", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Ollama läuft nicht — zuerst Ollama installieren und starten.",
            ])
        }
        try await ollama.pullModel(model) { progress in
            Task { @MainActor [weak self] in
                self?.set(id, state: .installing, progress: progress.fraction, message: progress.status)
            }
        }
    }

    nonisolated private func resolveBinaryPath(_ name: String) -> String? {
        let candidates = ["/opt/homebrew/bin/", "/usr/local/bin/", "/usr/bin/"]
        for dir in candidates where FileManager.default.isExecutableFile(atPath: dir + name) {
            return dir + name
        }
        return nil
    }

    private func runInstaller(_ command: [String], fallback: [String]?) async throws {
        do {
            try await runProcess(command)
        } catch {
            guard let fallback else { throw error }
            try await runProcess(fallback)
        }
    }

    private func runProcess(_ command: [String]) async throws {
        var command = command
        let name = command.removeFirst()
        guard let binary = resolveBinaryPath(name) else {
            throw NSError(domain: "Onboarding", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "\(name) nicht gefunden — bitte \(name) installieren.",
            ])
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: binary)
        process.arguments = command
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            process.terminationHandler = { _ in continuation.resume() }
        }
        guard process.terminationStatus == 0 else {
            let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            throw NSError(domain: "Onboarding", code: Int(process.terminationStatus), userInfo: [
                NSLocalizedDescriptionKey: String(output.suffix(300)),
            ])
        }
    }
}
