import Foundation

/// Creates a new self-contained episode folder from a Zencastr episode source
/// (design D10): enumerates every `recording-*` subfolder, copies all audio
/// into `Recordings/`, derives the episode number from the source folder name,
/// and generates the Reaper project from the configured template.
struct ZencastrIngest {
    /// Speaker mapping: first match wins, `fallbackTrack` catches the rest.
    struct SpeakerMap: Codable, Hashable {
        struct Rule: Codable, Hashable {
            var contains: String
            var track: String
        }
        var rules: [Rule]
        var fallbackTrack: String

        static let standard = SpeakerMap(
            rules: [
                Rule(contains: "laufendentdecken", track: "Peter"),
                Rule(contains: "florian", track: "Florian"),
            ],
            fallbackTrack: "Geordi"
        )

        func track(for fileName: String) -> String {
            let lowered = fileName.lowercased()
            for rule in rules where lowered.contains(rule.contains.lowercased()) {
                return rule.track
            }
            return fallbackTrack
        }
    }

    static let audioExtensions: Set<String> = ["wav", "flac", "mp3", "m4a"]

    enum IngestError: LocalizedError {
        case noRecordings
        case episodeFolderExists(String)

        var errorDescription: String? {
            switch self {
            case .noRecordings:
                return "Keine recording-* Ordner mit Audio im Zencastr-Ordner gefunden."
            case .episodeFolderExists(let name):
                return "Episodenordner \(name) existiert bereits."
            }
        }
    }

    let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    /// Episode number derived from the Zencastr source folder name (e.g. "259").
    static func episodeNumber(fromSource source: URL) -> String? {
        let name = source.lastPathComponent
        let digits = name.prefix { $0.isNumber }
        return digits.isEmpty ? nil : String(digits)
    }

    /// All audio files across every `recording-*` subfolder (and, as fallback,
    /// audio directly in the source folder).
    func collectAudioFiles(source: URL) throws -> [URL] {
        var audio: [URL] = []
        let entries = (try? fileManager.contentsOfDirectory(
            at: source, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]
        )) ?? []

        let recordingFolders = entries
            .filter { $0.lastPathComponent.lowercased().hasPrefix("recording") }
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }

        for folder in recordingFolders {
            let files = (try? fileManager.contentsOfDirectory(
                at: folder, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]
            )) ?? []
            audio += files.filter { Self.audioExtensions.contains($0.pathExtension.lowercased()) }
                .sorted { $0.lastPathComponent < $1.lastPathComponent }
        }

        if recordingFolders.isEmpty {
            audio = entries.filter { Self.audioExtensions.contains($0.pathExtension.lowercased()) }
                .sorted { $0.lastPathComponent < $1.lastPathComponent }
        }

        guard !audio.isEmpty else { throw IngestError.noRecordings }
        return audio
    }

    struct Result {
        var episodeFolder: URL
        var copiedFiles: [URL]
        var episodeNumber: String?
        var projectURL: URL?
    }

    /// Copies the Zencastr audio into `<root>/<slug>/Recordings/`. Duplicate
    /// file names across recording-* folders get a numeric suffix.
    func createEpisode(
        source: URL,
        storageRoot: URL,
        slug: String,
        copying audioFiles: [URL]? = nil
    ) throws -> Result {
        let episodeFolder = storageRoot.appendingPathComponent(slug, isDirectory: true)
        guard !fileManager.fileExists(atPath: episodeFolder.path) else {
            throw IngestError.episodeFolderExists(slug)
        }
        let recordings = episodeFolder.appendingPathComponent("Recordings", isDirectory: true)
        try fileManager.createDirectory(at: recordings, withIntermediateDirectories: true)

        let files = try audioFiles ?? collectAudioFiles(source: source)
        var copied: [URL] = []
        var usedNames: Set<String> = []
        for file in files {
            var name = file.lastPathComponent
            var counter = 2
            while usedNames.contains(name) {
                let base = file.deletingPathExtension().lastPathComponent
                name = "\(base)-\(counter).\(file.pathExtension)"
                counter += 1
            }
            usedNames.insert(name)
            let destination = recordings.appendingPathComponent(name)
            try fileManager.copyItem(at: file, to: destination)
            copied.append(destination)
        }

        return Result(
            episodeFolder: episodeFolder,
            copiedFiles: copied,
            episodeNumber: Self.episodeNumber(fromSource: source),
            projectURL: nil
        )
    }
}
