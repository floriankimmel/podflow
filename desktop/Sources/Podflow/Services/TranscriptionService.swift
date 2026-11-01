import Foundation

/// Local transcription (transcription spec): runs quicksubs with the parakeet
/// engine against the episode's primary audio and writes
/// `<slug>.transcript.txt` into the episode folder. The parakeet model is
/// downloaded by quicksubs itself on first use (~400 MB), no Ollama involved.
/// Stateful: skips when the transcript exists unless a re-run is forced.
struct TranscriptionService {
    enum TranscriptionError: LocalizedError {
        case engineMissing(String)
        case noAudio
        case commandFailed(String)

        var errorDescription: String? {
            switch self {
            case .engineMissing(let detail):
                return "Transkriptions-Engine fehlt: \(detail) — Onboarding ausführen."
            case .noAudio:
                return "Keine Audiodatei im Episodenordner gefunden."
            case .commandFailed(let output):
                return "Transkription fehlgeschlagen: \(output)"
            }
        }
    }

    /// Command template with {{audio}}, {{output}} and {{outputDir}} placeholders.
    let commandTemplate: String
    let fileManager: FileManager

    init(commandTemplate: String,
         fileManager: FileManager = .default) {
        self.commandTemplate = commandTemplate
        self.fileManager = fileManager
    }

    static func transcriptURL(episodeFolder: URL) -> URL {
        let slug = episodeFolder.lastPathComponent
        return episodeFolder.appendingPathComponent("\(slug).transcript.txt")
    }

    /// Engine availability check (task 1.1): the transcription binary must be
    /// resolvable; its speech model is self-managed (downloaded on first run).
    func checkEngine() async -> [String] {
        var missing: [String] = []
        let binary = commandTemplate.split(separator: " ").first.map(String.init) ?? ""
        if !binary.isEmpty, resolveBinary(binary) == nil {
            missing.append("\(binary) nicht installiert")
        }
        return missing
    }

    func resolveBinary(_ name: String) -> String? {
        if name.hasPrefix("/") {
            return fileManager.isExecutableFile(atPath: name) ? name : nil
        }
        let candidates = ["/opt/homebrew/bin/", "/usr/local/bin/", "/usr/bin/"]
        for dir in candidates where fileManager.isExecutableFile(atPath: dir + name) {
            return dir + name
        }
        if let path = ProcessInfo.processInfo.environment["PATH"] {
            for dir in path.split(separator: ":") {
                let candidate = String(dir) + "/" + name
                if fileManager.isExecutableFile(atPath: candidate) { return candidate }
            }
        }
        return nil
    }

    /// Primary audio for transcription: prefer the final m4a/mp3 export, fall
    /// back to wav/flac in the folder root (task 1.2).
    func primaryAudio(in episodeFolder: URL) -> URL? {
        guard let files = try? fileManager.contentsOfDirectory(
            at: episodeFolder, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]
        ) else { return nil }
        let byExtension: (String) -> URL? = { ext in
            files.filter { $0.pathExtension.lowercased() == ext }
                .sorted { $0.lastPathComponent < $1.lastPathComponent }
                .first
        }
        for ext in ["m4a", "mp3", "wav", "flac"] {
            if let found = byExtension(ext) { return found }
        }
        return nil
    }

    /// Runs the transcription; returns the transcript text.
    func transcribe(episodeFolder: URL, force: Bool = false) async throws -> String {
        let transcriptURL = Self.transcriptURL(episodeFolder: episodeFolder)
        if !force, let existing = try? String(contentsOf: transcriptURL, encoding: .utf8), !existing.isEmpty {
            return existing
        }

        let missing = await checkEngine()
        guard missing.isEmpty else {
            throw TranscriptionError.engineMissing(missing.joined(separator: ", "))
        }
        guard let audio = primaryAudio(in: episodeFolder) else {
            throw TranscriptionError.noAudio
        }

        let command = PromptStore.substitute(commandTemplate, values: [
            "audio": audio.path,
            "output": transcriptURL.path,
            "outputDir": episodeFolder.path,
        ])
        var parts = command.split(separator: " ").map(String.init)
        guard let binary = resolveBinary(parts.removeFirst()) else {
            throw TranscriptionError.engineMissing("Binary nicht gefunden")
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: binary)
        process.arguments = parts
        process.currentDirectoryURL = episodeFolder
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            process.terminationHandler = { _ in continuation.resume() }
        }
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        guard process.terminationStatus == 0 else {
            throw TranscriptionError.commandFailed(String(output.suffix(400)))
        }

        if let transcript = try? String(contentsOf: transcriptURL, encoding: .utf8), !transcript.isEmpty {
            return transcript
        }
        // quicksubs writes `<audio-basename>.txt` (no custom filename flag):
        // adopt it as the canonical transcript.
        let baseName = audio.deletingPathExtension().lastPathComponent
        for candidate in [episodeFolder.appendingPathComponent("\(baseName).txt"),
                          audio.deletingPathExtension().appendingPathExtension("txt")] {
            if let text = try? String(contentsOf: candidate, encoding: .utf8), !text.isEmpty {
                try text.write(to: transcriptURL, atomically: true, encoding: .utf8)
                try? fileManager.removeItem(at: candidate)
                return text
            }
        }
        // Tool printed to stdout instead of writing the file: persist it.
        guard !output.isEmpty else { throw TranscriptionError.commandFailed("leeres Transkript") }
        try output.write(to: transcriptURL, atomically: true, encoding: .utf8)
        return output
    }
}
