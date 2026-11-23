import Foundation

/// Runs the plugin's episode skill headless in an episode folder:
/// `claude -p "/podflow:episode <mode>" --plugin-dir <plugin> --output-format stream-json …`.
/// Progress per step comes from `state.json`; this turns the JSON stream into
/// readable log lines and keeps the raw stream in `run.log`.
struct ClaudeRunner {
    enum RunnerError: LocalizedError {
        case claudeMissing
        case pluginMissing
        case cliMissing

        var errorDescription: String? {
            switch self {
            case .claudeMissing: return "Claude Code ist nicht installiert. Bitte die Einrichtung erneut ausführen."
            case .pluginMissing: return "Das Podflow-Plugin fehlt in der App. Bitte die App neu installieren."
            case .cliMissing: return "Das podflow-Werkzeug fehlt in der App. Bitte die App neu installieren."
            }
        }
    }

    struct Outcome: Sendable {
        var exitCode: Int32
        /// The final result text Claude reported, if any.
        var summary: String
        var isError: Bool
    }

    let setup: ClaudeSetup
    let pluginDirectory: URL?
    let cliPath: String?

    init(
        setup: ClaudeSetup = ClaudeSetup(),
        pluginDirectory: URL? = AppResources.pluginDirectory,
        cliPath: String? = AppResources.cliPath
    ) {
        self.setup = setup
        self.pluginDirectory = pluginDirectory
        self.cliPath = cliPath
    }

    static func arguments(mode: RunMode, pluginDirectory: URL) -> [String] {
        [
            "-p", "/podflow:episode \(mode.rawValue)",
            "--plugin-dir", pluginDirectory.path,
            "--output-format", "stream-json",
            "--verbose",
            "--dangerously-skip-permissions",
        ]
    }

    func run(
        mode: RunMode,
        episodeFolder: URL,
        environment extra: [String: String],
        onLog: @escaping @Sendable (String) -> Void
    ) async throws -> Outcome {
        guard let binary = setup.findBinary() else { throw RunnerError.claudeMissing }
        guard let pluginDirectory else { throw RunnerError.pluginMissing }
        guard let cliPath else { throw RunnerError.cliMissing }

        var environment = extra
        environment[EnvName.cli] = cliPath

        let logURL = episodeFolder.appendingPathComponent(EpisodeFile.runLog)
        FileManager.default.createFile(atPath: logURL.path, contents: nil)
        let logHandle = try? FileHandle(forWritingTo: logURL)
        defer { try? logHandle?.close() }

        let parser = StreamParser()
        let result = try await ProcessRunner.run(
            binary,
            Self.arguments(mode: mode, pluginDirectory: pluginDirectory),
            environment: ProcessRunner.environment(adding: environment),
            currentDirectory: episodeFolder,
            onOutput: { chunk in
                try? logHandle?.write(contentsOf: Data(chunk.utf8))
                for line in parser.feed(chunk) { onLog(line) }
            }
        )
        return Outcome(exitCode: result.exitCode, summary: parser.summary, isError: parser.isError || result.exitCode != 0)
    }
}

/// Turns Claude Code's `stream-json` lines into short human-readable log lines.
final class StreamParser: @unchecked Sendable {
    private let lock = NSLock()
    private var buffer = ""
    private var resultText = ""
    private var resultIsError = false

    var summary: String {
        lock.lock()
        defer { lock.unlock() }
        return resultText
    }

    var isError: Bool {
        lock.lock()
        defer { lock.unlock() }
        return resultIsError
    }

    /// Feeds a chunk of process output; returns the log lines it completed.
    func feed(_ chunk: String) -> [String] {
        lock.lock()
        defer { lock.unlock() }
        buffer += chunk
        var lines: [String] = []
        while let newline = buffer.firstIndex(of: "\n") {
            let line = String(buffer[..<newline])
            buffer = String(buffer[buffer.index(after: newline)...])
            lines.append(contentsOf: parse(line))
        }
        return lines
    }

    private func parse(_ line: String) -> [String] {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return [] }
        guard let data = trimmed.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            // Not JSON (e.g. a CLI error before streaming starts): show as is.
            return [trimmed]
        }
        switch json["type"] as? String {
        case "assistant":
            let message = json["message"] as? [String: Any]
            let content = message?["content"] as? [[String: Any]] ?? []
            return content.compactMap(Self.describe)
        case "result":
            resultText = json["result"] as? String ?? ""
            resultIsError = json["is_error"] as? Bool ?? false
            return []
        default:
            return []
        }
    }

    private static func describe(_ block: [String: Any]) -> String? {
        switch block["type"] as? String {
        case "text":
            let text = (block["text"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? nil : text
        case "tool_use":
            let name = block["name"] as? String ?? "Tool"
            let input = block["input"] as? [String: Any] ?? [:]
            let detail = (input["description"] as? String)
                ?? (input["command"] as? String)
                ?? (input["file_path"] as? String)
                ?? ""
            let short = detail.split(separator: "\n").first.map(String.init) ?? ""
            return short.isEmpty ? "› \(name)" : "› \(name): \(short.prefix(140))"
        default:
            return nil
        }
    }
}

/// Locations of the plugin and the bundled CLI: inside the app bundle when
/// packaged (`make app`), otherwise the repository checkout for `swift run`.
enum AppResources {
    static var pluginDirectory: URL? {
        if let override = ProcessInfo.processInfo.environment["PODFLOW_PLUGIN_DIR"] {
            return existingDirectory(URL(fileURLWithPath: override))
        }
        if let bundled = Bundle.main.resourceURL?.appendingPathComponent("plugin"),
           let found = existingDirectory(bundled) {
            return found
        }
        return existingDirectory(repositoryDesktopDirectory.appendingPathComponent("plugin"))
    }

    static var cliPath: String? {
        let fileManager = FileManager.default
        if let override = ProcessInfo.processInfo.environment["PODFLOW_CLI"], fileManager.isExecutableFile(atPath: override) {
            return override
        }
        if let bundled = Bundle.main.resourceURL?.appendingPathComponent("podflow").path,
           fileManager.isExecutableFile(atPath: bundled) {
            return bundled
        }
        let development = repositoryDesktopDirectory.appendingPathComponent("build/podflow").path
        return fileManager.isExecutableFile(atPath: development) ? development : nil
    }

    /// `desktop/` in the checkout this binary was compiled from.
    private static var repositoryDesktopDirectory: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // Services
            .deletingLastPathComponent() // Podflow
            .deletingLastPathComponent() // Sources
            .deletingLastPathComponent() // desktop
    }

    private static func existingDirectory(_ url: URL) -> URL? {
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
        return exists && isDirectory.boolValue ? url : nil
    }
}
