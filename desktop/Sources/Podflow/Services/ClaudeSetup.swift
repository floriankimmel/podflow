import Foundation

/// Runs a process to completion and collects its output.
enum ProcessRunner {
    struct Result: Sendable {
        var exitCode: Int32
        var output: String
    }

    /// GUI apps start with a minimal PATH; add the usual tool locations.
    static func environment(adding extra: [String: String] = [:]) -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        let home = NSHomeDirectory()
        let extraPaths = ["\(home)/.local/bin", "/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin", "/usr/sbin", "/sbin"]
        let current = (environment["PATH"] ?? "").split(separator: ":").map(String.init)
        environment["PATH"] = (current + extraPaths.filter { !current.contains($0) }).joined(separator: ":")
        for (key, value) in extra { environment[key] = value }
        return environment
    }

    static func run(
        _ executable: String,
        _ arguments: [String],
        environment: [String: String] = ProcessRunner.environment(),
        currentDirectory: URL? = nil,
        onOutput: (@Sendable (String) -> Void)? = nil
    ) async throws -> Result {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.environment = environment
        process.currentDirectoryURL = currentDirectory
        process.standardInput = FileHandle.nullDevice

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        let collected = OutputBox()
        let handle = pipe.fileHandleForReading
        handle.readabilityHandler = { fileHandle in
            let data = fileHandle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            collected.append(text)
            onOutput?(text)
        }

        try process.run()
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            process.terminationHandler = { _ in continuation.resume() }
        }
        handle.readabilityHandler = nil
        if let rest = try? handle.readToEnd(), let text = String(data: rest, encoding: .utf8), !text.isEmpty {
            collected.append(text)
            onOutput?(text)
        }
        return Result(exitCode: process.terminationStatus, output: collected.value)
    }
}

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

/// Finds, installs and signs in Claude Code so the user never needs a terminal.
struct ClaudeSetup {
    enum Status: Equatable, Sendable {
        case missing
        case loggedOut
        case ready
    }

    enum SetupError: LocalizedError {
        case installFailed(String)
        case loginFailed(String)

        var errorDescription: String? {
            switch self {
            case .installFailed(let output):
                return "Claude Code konnte nicht installiert werden.\n\(output.suffix(400))"
            case .loginFailed(let output):
                return "Die Anmeldung bei Claude hat nicht geklappt.\n\(output.suffix(400))"
            }
        }
    }

    static let installCommand = "curl -fsSL https://claude.ai/install.sh | bash"

    let fileManager: FileManager
    /// Overrides binary resolution (tests use a fake `claude` script).
    let binaryOverride: String?

    init(fileManager: FileManager = .default, binaryOverride: String? = nil) {
        self.fileManager = fileManager
        self.binaryOverride = binaryOverride
    }

    func findBinary() -> String? {
        if let binaryOverride { return fileManager.isExecutableFile(atPath: binaryOverride) ? binaryOverride : nil }
        let home = NSHomeDirectory()
        let candidates = [
            "\(home)/.local/bin/claude",
            "\(home)/.claude/local/claude",
            "/opt/homebrew/bin/claude",
            "/usr/local/bin/claude",
        ]
        if let found = candidates.first(where: { fileManager.isExecutableFile(atPath: $0) }) { return found }
        for directory in (ProcessInfo.processInfo.environment["PATH"] ?? "").split(separator: ":") {
            let candidate = "\(directory)/claude"
            if fileManager.isExecutableFile(atPath: candidate) { return candidate }
        }
        return nil
    }

    func status() async -> Status {
        guard let binary = findBinary() else { return .missing }
        guard let result = try? await ProcessRunner.run(binary, ["auth", "status"]) else { return .loggedOut }
        return Self.isLoggedIn(authStatusOutput: result.output) ? .ready : .loggedOut
    }

    /// `claude auth status` prints JSON with a `loggedIn` flag.
    static func isLoggedIn(authStatusOutput: String) -> Bool {
        guard let start = authStatusOutput.firstIndex(of: "{"),
              let data = String(authStatusOutput[start...]).data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return false }
        return json["loggedIn"] as? Bool == true
    }

    /// Runs the official native installer.
    func install(onOutput: (@Sendable (String) -> Void)? = nil) async throws {
        let result = try await ProcessRunner.run("/bin/bash", ["-c", Self.installCommand], onOutput: onOutput)
        guard result.exitCode == 0, findBinary() != nil else { throw SetupError.installFailed(result.output) }
    }

    /// Starts the browser login and waits until the user finished it.
    func login(onOutput: (@Sendable (String) -> Void)? = nil) async throws {
        guard let binary = findBinary() else { throw SetupError.loginFailed("claude nicht gefunden") }
        let result = try await ProcessRunner.run(binary, ["auth", "login"], onOutput: onOutput)
        guard result.exitCode == 0 else { throw SetupError.loginFailed(result.output) }
    }
}
