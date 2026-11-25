import Foundation
import Yams

/// Prepares an episode folder for the bundled `podflow publish`:
/// a per-episode config under `~/.config/podflow/` (the CLI only reads configs
/// from there, selected by file name via `PODFLOW_CONFIG_FILE`) and the CLI's
/// `<folder>.state.yml` with the metadata it would otherwise ask for.
struct PublishConfig {
    struct Inputs: Equatable {
        var number: String
        var title: String
        var audioBasename: String
        var releaseDate: Date
        /// File names inside the episode folder.
        var coverFile: String
        var featuredFile: String
        var wordpressServer: String
        var ftpHost: String
        var ftpPort: String
        var coverBaseURL: String
    }

    let configDirectory: URL
    let fileManager: FileManager

    static var defaultConfigDirectory: URL {
        URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".config/podflow", isDirectory: true)
    }

    init(configDirectory: URL = PublishConfig.defaultConfigDirectory, fileManager: FileManager = .default) {
        self.configDirectory = configDirectory
        self.fileManager = fileManager
    }

    static func configFileName(number: String) -> String {
        "episode-\(number).yml"
    }

    /// Removes the per-episode CLI config of a deleted episode.
    func remove(number: String) {
        try? fileManager.removeItem(at: configDirectory.appendingPathComponent(Self.configFileName(number: number)))
    }

    /// The CLI schedules with this exact format ("2006-01-02 15:04:05").
    static func formatReleaseDate(_ date: Date, timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }

    /// Config with two steps: FTP upload of the podcast cover, then WordPress.
    /// Secrets stay `{{env.*}}` references; the CLI resolves them at run time.
    static func configYAML(_ inputs: Inputs) throws -> String {
        let coverExtension = (inputs.coverFile as NSString).pathExtension
        let coverTarget = "\(inputs.audioBasename).\(coverExtension)"
        let coverBase = inputs.coverBaseURL.hasSuffix("/") ? inputs.coverBaseURL : inputs.coverBaseURL + "/"

        func env(_ secret: SettingsStore.Secret) -> String { "{{env.\(secret.rawValue)}}" }
        func file(_ name: String, _ fileName: String) -> [String: Any] {
            ["name": name, "fileName": fileName, "required": true]
        }

        let config: [String: Any] = [
            "currentEpisode": inputs.number,
            "files": [
                file("Shownotes", EpisodeFile.shownotes),
                file("SEO", EpisodeFile.seo),
                file("Cover", inputs.coverFile),
                file("WordPress-Bild", inputs.featuredFile),
                file("Kapitel", EpisodeFile.chapters),
            ],
            "steps": [
                ["ftp": [
                    "host": inputs.ftpHost,
                    "port": inputs.ftpPort,
                    "username": env(.ftpUser),
                    "password": env(.ftpPassword),
                    "files": [["source": inputs.coverFile, "target": coverTarget]],
                ]],
                ["wordpress": [
                    "apiKey": env(.wordpressKey),
                    "server": inputs.wordpressServer,
                    "image": inputs.featuredFile,
                    "poster": coverBase + coverTarget,
                    "episode": inputs.audioBasename,
                    "showNotes": EpisodeFile.shownotes,
                    "chapter": EpisodeFile.chapters,
                    "contentFile": EpisodeFile.seo,
                ]],
            ],
        ]
        return try Yams.dump(object: config, sortKeys: true)
    }

    /// Writes config, CLI state metadata and the (empty) chapters file.
    /// Returns the `PODFLOW_CONFIG_FILE` value for the run.
    @discardableResult
    func write(_ inputs: Inputs, episodeFolder: URL) throws -> String {
        try fileManager.createDirectory(at: configDirectory, withIntermediateDirectories: true)
        let fileName = Self.configFileName(number: inputs.number)
        try Self.configYAML(inputs).write(
            to: configDirectory.appendingPathComponent(fileName), atomically: true, encoding: .utf8)

        // The CLI panics without a chapters file; an empty one means "no chapters".
        let chapters = episodeFolder.appendingPathComponent(EpisodeFile.chapters)
        if !fileManager.fileExists(atPath: chapters.path) {
            try "".write(to: chapters, atomically: true, encoding: .utf8)
        }

        try writeCLIState(inputs, episodeFolder: episodeFolder)
        return fileName
    }

    /// Merges metadata into `<folder>.state.yml`, keeping progress the CLI
    /// already recorded (WordPress ids, finished steps) so a retry resumes.
    func writeCLIState(_ inputs: Inputs, episodeFolder: URL) throws {
        let url = episodeFolder.appendingPathComponent("\(episodeFolder.lastPathComponent).state.yml")
        var state: [String: Any] = [:]
        if let text = try? String(contentsOf: url, encoding: .utf8),
           let existing = try? Yams.load(yaml: text) as? [String: Any] {
            state = existing
        }
        state["metadata"] = [
            "episodeNumber": inputs.number,
            "releaseDate": Self.formatReleaseDate(inputs.releaseDate),
            "title": inputs.title,
        ]
        try Yams.dump(object: state, sortKeys: true).write(to: url, atomically: true, encoding: .utf8)
    }
}
