import Foundation

/// Launches the installed `podflow` binary in an episode's folder (D8) with a
/// preset's configuration materialized for the run (config-presets D2).
///
/// The CLI resolves PODFLOW_CONFIG_FILE as a file name under
/// ~/.config/podflow/, so presets are written there as per-run files and the
/// global config.yml is never touched.
final class PodflowRunner {
    struct RunResult {
        var exitCode: Int32
        var output: String
    }

    enum RunnerError: LocalizedError {
        case binaryNotFound
        case configWriteFailed(String)

        var errorDescription: String? {
            switch self {
            case .binaryNotFound:
                return "podflow CLI nicht gefunden. Onboarding ausführen oder PATH prüfen."
            case .configWriteFailed(let reason):
                return "Preset-Konfiguration konnte nicht geschrieben werden: \(reason)"
            }
        }
    }

    let fileManager: FileManager
    /// Overrides binary resolution (tests use a fake podflow script).
    let binaryOverride: String?

    init(fileManager: FileManager = .default, binaryOverride: String? = nil) {
        self.fileManager = fileManager
        self.binaryOverride = binaryOverride
    }

    static func findPodflowBinary() -> String? {
        let candidates = [
            "/opt/homebrew/bin/podflow",
            "/usr/local/bin/podflow",
            (NSHomeDirectory() as NSString).appendingPathComponent("go/bin/podflow"),
        ]
        for path in candidates where FileManager.default.isExecutableFile(atPath: path) {
            return path
        }
        // PATH lookup
        if let path = ProcessInfo.processInfo.environment["PATH"] {
            for dir in path.split(separator: ":") {
                let candidate = String(dir) + "/podflow"
                if FileManager.default.isExecutableFile(atPath: candidate) { return candidate }
            }
        }
        return nil
    }

    private var configDirectory: URL {
        URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent(".config/podflow", isDirectory: true)
    }

    /// Writes the preset's configuration as a per-run config file and returns
    /// the PODFLOW_CONFIG_FILE value (a file name relative to ~/.config/podflow).
    func materializeConfig(_ config: PodflowConfig, runID: String) throws -> String {
        let fileName = "preset-run-\(runID).yml"
        do {
            try fileManager.createDirectory(at: configDirectory, withIntermediateDirectories: true)
            let yaml = try PresetStore.serializeConfiguration(config)
            try yaml.write(to: configDirectory.appendingPathComponent(fileName), atomically: true, encoding: .utf8)
        } catch {
            throw RunnerError.configWriteFailed(String(describing: error))
        }
        return fileName
    }

    func cleanupConfig(fileName: String) {
        try? fileManager.removeItem(at: configDirectory.appendingPathComponent(fileName))
    }

    /// Runs `podflow <command>` with cwd = episode folder, streaming output.
    /// `configuration` is the applied preset config (profile-filtered);
    /// `backend` lets the run report to the shared backend.
    func run(
        command: [String],
        episodeFolder: URL,
        configuration: PodflowConfig?,
        backendURL: String?,
        workspaceKey: String?,
        onOutput: (@Sendable (String) -> Void)? = nil
    ) async throws -> RunResult {
        guard let binary = binaryOverride ?? Self.findPodflowBinary() else { throw RunnerError.binaryNotFound }

        var configFileName: String?
        if let configuration {
            configFileName = try materializeConfig(configuration, runID: UUID().uuidString)
        }
        defer { configFileName.map(cleanupConfig) }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: binary)
        process.arguments = command
        process.currentDirectoryURL = episodeFolder

        var environment = ProcessInfo.processInfo.environment
        if let configFileName {
            environment["PODFLOW_CONFIG_FILE"] = configFileName
        }
        if let backendURL, !backendURL.isEmpty {
            environment["PODFLOW_BACKEND_URL"] = backendURL
        }
        if let workspaceKey, !workspaceKey.isEmpty {
            environment["PODFLOW_WORKSPACE_KEY"] = workspaceKey
        }
        process.environment = environment

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        final class OutputBox: @unchecked Sendable {
            private let lock = NSLock()
            private var text = ""
            func append(_ chunk: String) {
                lock.lock()
                text += chunk
                lock.unlock()
            }
            var value: String {
                lock.lock()
                defer { lock.unlock() }
                return text
            }
        }
        let collected = OutputBox()
        let handle = pipe.fileHandleForReading
        handle.readabilityHandler = { fileHandle in
            let data = fileHandle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            onOutput?(text)
            collected.append(text)
        }

        try process.run()
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            process.terminationHandler = { _ in continuation.resume() }
        }
        handle.readabilityHandler = nil
        if let rest = try? handle.readToEnd(), let text = String(data: rest, encoding: .utf8), !text.isEmpty {
            onOutput?(text)
            collected.append(text)
        }
        return RunResult(exitCode: process.terminationStatus, output: collected.value)
    }
}
