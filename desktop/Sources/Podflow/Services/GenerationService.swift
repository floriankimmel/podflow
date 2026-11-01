import Foundation

/// Model-target abstraction (design D3): local Ollama by default, a command
/// runner (pi coding agent) or cloud model as configurable alternatives.
protocol TextModelRunner: Sendable {
    func run(prompt: String) async throws -> String
}

struct OllamaModelRunner: TextModelRunner {
    var ollama: OllamaClient
    var model: String

    func run(prompt: String) async throws -> String {
        try await ollama.generate(model: model, prompt: prompt)
    }
}

/// Runs prompts through the Claude Code CLI (`claude -p`), prompt via stdin.
/// Uses the user's claude login; no API key handling in the app.
struct ClaudeCodeModelRunner: TextModelRunner {
    enum ClaudeError: LocalizedError {
        case binaryMissing
        case failed(String)

        var errorDescription: String? {
            switch self {
            case .binaryMissing:
                return "claude CLI nicht gefunden — Claude Code installieren (Onboarding)."
            case .failed(let output):
                return "Claude Code fehlgeschlagen: \(output)"
            }
        }
    }

    static func resolveBinary() -> String? {
        let candidates = ["/opt/homebrew/bin/claude", "/usr/local/bin/claude",
                          NSHomeDirectory() + "/.local/bin/claude",
                          NSHomeDirectory() + "/.claude/local/claude"]
        for path in candidates where FileManager.default.isExecutableFile(atPath: path) {
            return path
        }
        if let path = ProcessInfo.processInfo.environment["PATH"] {
            for dir in path.split(separator: ":") {
                let candidate = String(dir) + "/claude"
                if FileManager.default.isExecutableFile(atPath: candidate) { return candidate }
            }
        }
        return nil
    }

    func run(prompt: String) async throws -> String {
        guard let binary = Self.resolveBinary() else { throw ClaudeError.binaryMissing }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: binary)
        process.arguments = ["-p", "--output-format", "text"]
        let stdin = Pipe()
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardInput = stdin
        process.standardOutput = stdout
        process.standardError = stderr
        try process.run()
        stdin.fileHandleForWriting.write(Data(prompt.utf8))
        stdin.fileHandleForWriting.closeFile()
        let outputData = stdout.fileHandleForReading.readDataToEndOfFile()
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            process.terminationHandler = { _ in continuation.resume() }
        }
        guard process.terminationStatus == 0 else {
            let error = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            throw ClaudeError.failed(String(error.suffix(300)))
        }
        return String(data: outputData, encoding: .utf8) ?? ""
    }
}

/// Content generation (content-generation spec): transcript → shownotes →
/// social (6 platforms) → SEO. Each step is stateful (skip when its file
/// exists), independently re-runnable, and writes podflow-readable output.
struct GenerationService {
    enum GenerationError: LocalizedError {
        case missingTranscript
        case missingShownotes
        case modelMissing(String)
        case emptyResult(String)

        var errorDescription: String? {
            switch self {
            case .missingTranscript: return "Kein Transkript vorhanden — zuerst transkribieren."
            case .missingShownotes: return "Keine Shownotes vorhanden — zuerst Shownotes generieren."
            case .modelMissing(let model): return "Generierungs-Modell \(model) fehlt — Onboarding ausführen."
            case .emptyResult(let step): return "Leeres Ergebnis bei \(step) — erneut versuchen."
            }
        }
    }

    let runner: TextModelRunner
    let prompts: PromptStore
    let fileManager: FileManager

    init(runner: TextModelRunner, prompts: PromptStore = PromptStore(), fileManager: FileManager = .default) {
        self.runner = runner
        self.prompts = prompts
        self.fileManager = fileManager
    }

    // MARK: Output file locations

    /// Shownotes path: podflow's configured wordpress.showNotes (with
    /// placeholders resolved), falling back to `<slug>.md` (design D5).
    static func shownotesURL(episodeFolder: URL, config: PodflowConfig?, episodeNumber: String?) -> URL {
        let slug = episodeFolder.lastPathComponent
        if let path = config?.shownotesPath {
            let resolved = resolvePlaceholders(path, slug: slug, episodeNumber: episodeNumber)
            return url(for: resolved, episodeFolder: episodeFolder)
        }
        return episodeFolder.appendingPathComponent("\(slug).md")
    }

    /// SEO content file: podflow's configured wordpress.contentFile (parsed by
    /// the CLI for **Meta-Description:** / **Focus Keywords:**), falling back
    /// to `content-<slug>.md`.
    static func seoURL(episodeFolder: URL, config: PodflowConfig?, episodeNumber: String?) -> URL {
        let slug = episodeFolder.lastPathComponent
        if let path = config?.contentFilePath {
            let resolved = resolvePlaceholders(path, slug: slug, episodeNumber: episodeNumber)
            return url(for: resolved, episodeFolder: episodeFolder)
        }
        return episodeFolder.appendingPathComponent("content-\(slug).md")
    }

    static func socialURL(episodeFolder: URL) -> URL {
        episodeFolder.appendingPathComponent("\(episodeFolder.lastPathComponent).social.md")
    }

    private static func resolvePlaceholders(_ path: String, slug: String, episodeNumber: String?) -> String {
        var result = path.replacingOccurrences(of: "{{folderName}}", with: slug)
        result = result.replacingOccurrences(of: "{{episodeNumber}}", with: episodeNumber ?? "")
        return result
    }

    private static func url(for path: String, episodeFolder: URL) -> URL {
        path.hasPrefix("/")
            ? URL(fileURLWithPath: path)
            : episodeFolder.appendingPathComponent(path)
    }

    // MARK: Steps

    /// Shownotes from the transcript (prompt 01). Returns the Markdown.
    func generateShownotes(
        episodeFolder: URL, episodeNumber: String?, config: PodflowConfig?, force: Bool = false
    ) async throws -> String {
        let output = Self.shownotesURL(episodeFolder: episodeFolder, config: config, episodeNumber: episodeNumber)
        if !force, let existing = try? String(contentsOf: output, encoding: .utf8), !existing.isEmpty {
            return existing
        }
        let transcriptURL = TranscriptionService.transcriptURL(episodeFolder: episodeFolder)
        guard let transcript = try? String(contentsOf: transcriptURL, encoding: .utf8), !transcript.isEmpty else {
            throw GenerationError.missingTranscript
        }
        let template = try prompts.text(for: .shownotes)
        let prompt = PromptStore.substitute(template, values: [
            "episode_number": episodeNumber ?? "",
            "transcript": transcript,
        ])
        let result = try await runner.run(prompt: prompt).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !result.isEmpty else { throw GenerationError.emptyResult("Shownotes") }
        try fileManager.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
        try result.write(to: output, atomically: true, encoding: .utf8)
        return result
    }

    /// Social posts for all six platforms from the shownotes (prompt 02).
    /// Returns the posts keyed by lowercase platform name.
    func generateSocial(
        episodeFolder: URL, episodeNumber: String?, config: PodflowConfig?, force: Bool = false
    ) async throws -> [String: String] {
        let output = Self.socialURL(episodeFolder: episodeFolder)
        if !force, let existing = try? String(contentsOf: output, encoding: .utf8), !existing.isEmpty {
            return Self.parseSocialPosts(existing)
        }
        let shownotesURL = Self.shownotesURL(episodeFolder: episodeFolder, config: config, episodeNumber: episodeNumber)
        guard let shownotes = try? String(contentsOf: shownotesURL, encoding: .utf8), !shownotes.isEmpty else {
            throw GenerationError.missingShownotes
        }
        let template = try prompts.text(for: .socialMedia)
        let prompt = PromptStore.substitute(template, values: [
            "episode_number": episodeNumber ?? "",
            "shownotes": shownotes,
        ])
        let result = try await runner.run(prompt: prompt).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !result.isEmpty else { throw GenerationError.emptyResult("Social") }
        try result.write(to: output, atomically: true, encoding: .utf8)
        return Self.parseSocialPosts(result)
    }

    /// SEO/metadata from the shownotes (prompt 03), written in the
    /// podflow-readable `**Meta-Description:**` / `**Focus Keywords:**` form.
    func generateSEO(
        episodeFolder: URL, episodeNumber: String?, config: PodflowConfig?, force: Bool = false
    ) async throws -> String {
        let output = Self.seoURL(episodeFolder: episodeFolder, config: config, episodeNumber: episodeNumber)
        if !force, let existing = try? String(contentsOf: output, encoding: .utf8), !existing.isEmpty {
            return existing
        }
        let shownotesURL = Self.shownotesURL(episodeFolder: episodeFolder, config: config, episodeNumber: episodeNumber)
        guard let shownotes = try? String(contentsOf: shownotesURL, encoding: .utf8), !shownotes.isEmpty else {
            throw GenerationError.missingShownotes
        }
        let template = try prompts.text(for: .seo)
        let prompt = PromptStore.substitute(template, values: [
            "episode_number": episodeNumber ?? "",
            "text": shownotes,
        ])
        let result = try await runner.run(prompt: prompt).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !result.isEmpty else { throw GenerationError.emptyResult("SEO") }
        try fileManager.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
        try result.write(to: output, atomically: true, encoding: .utf8)
        return result
    }

    /// Parses the `## Platform` sections of the social output.
    static func parseSocialPosts(_ text: String) -> [String: String] {
        var posts: [String: String] = [:]
        var currentPlatform: String?
        var currentLines: [String] = []
        func flush() {
            if let platform = currentPlatform {
                posts[platform] = currentLines.joined(separator: "\n")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
            currentLines = []
        }
        for line in text.components(separatedBy: "\n") {
            if line.hasPrefix("## ") {
                flush()
                currentPlatform = String(line.dropFirst(3))
                    .trimmingCharacters(in: .whitespaces)
                    .lowercased()
            } else if currentPlatform != nil {
                currentLines.append(line)
            }
        }
        flush()
        return posts
    }

    /// The YouTube description from the SEO output, pushed into Auphonic
    /// metadata for the video profile (auphonic-video-ingest D4).
    static func youtubeDescription(fromSEO seo: String) -> String? {
        guard let range = seo.range(of: "**YouTube Beschreibung:**") else { return nil }
        let after = seo[range.upperBound...]
        let end = after.range(of: "**YouTube Tags:**")?.lowerBound ?? after.endIndex
        let description = after[..<end].trimmingCharacters(in: .whitespacesAndNewlines)
        return description.isEmpty ? nil : description
    }
}
