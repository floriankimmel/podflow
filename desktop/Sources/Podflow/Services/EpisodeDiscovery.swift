import Foundation
import Yams

/// Discovers episodes as the immediate subfolders of the storage root (D8) and
/// reads each episode's local `<slug>.state.yml` (falling back to any
/// `*.state.yml` or `state.yml` already in the folder) plus app-side metadata.
struct EpisodeDiscovery {
    let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    /// App-side per-episode settings (profile, preset) stored as
    /// `.podflow-app.json` inside the episode folder.
    struct AppMetadata: Codable {
        var profile: String?
        var presetID: String?
    }

    static let appMetadataFileName = ".podflow-app.json"

    /// Maps the CLI's boolean state.yml flags to pipeline stage keys.
    static let stateFlagToStep: [String: String] = [
        "ftpUploaded": "ftp_upload",
        "downloaded": "download",
        "s3Uploaded": "s3",
        "wordpressBlogCreated": "wordpress",
        "steadyHqCreated": "steady",
        "auphonicProduction": "auphonic",
    ]

    func listEpisodes(root: URL) -> [LocalEpisode] {
        guard let entries = try? fileManager.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        return entries
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
            .map { episode(at: $0) }
            .sorted { lhs, rhs in
                let l = Int(lhs.episodeNumber ?? "") ?? -1
                let r = Int(rhs.episodeNumber ?? "") ?? -1
                if l != r { return l > r }
                return lhs.slug.localizedStandardCompare(rhs.slug) == .orderedDescending
            }
    }

    func episode(at folderURL: URL) -> LocalEpisode {
        var episode = LocalEpisode(folderURL: folderURL)

        // state.yml metadata + publish flags (written by the CLI)
        if let stateURL = stateFileURL(in: folderURL, slug: episode.slug),
           let text = try? String(contentsOf: stateURL, encoding: .utf8),
           let yaml = try? Yams.load(yaml: text) as? [String: Any] {
            if let metadata = yaml["metadata"] as? [String: Any] {
                episode.episodeNumber = (metadata["episodeNumber"] as? String)
                    ?? (metadata["episodeNumber"] as? Int).map(String.init)
                episode.title = metadata["title"] as? String
                episode.releaseDate = metadata["releaseDate"] as? String
            }
            for (flag, step) in Self.stateFlagToStep where yaml[flag] as? Bool == true {
                episode.doneSteps.insert(step)
            }
        }

        // Fallback: leading digits of the folder name ("259_titel" → 259).
        if episode.episodeNumber == nil {
            let digits = episode.slug.prefix { $0.isNumber }
            if !digits.isEmpty { episode.episodeNumber = String(digits) }
        }

        // Stages whose artifacts already exist on disk count as done.
        episode.doneSteps.formUnion(stepsDerivedFromFiles(in: folderURL, slug: episode.slug))

        // App metadata (profile, preset)
        let appMetaURL = folderURL.appendingPathComponent(Self.appMetadataFileName)
        if let data = try? Data(contentsOf: appMetaURL),
           let meta = try? JSONDecoder().decode(AppMetadata.self, from: data) {
            episode.profileID = meta.profile
            episode.presetID = meta.presetID
        }

        return episode
    }

    /// Derives done stages from files in the folder: ingest (Recordings/ has
    /// content), reaper (edited .m4a export), transcribe/shownotes/social/seo
    /// (their default output files, design D5).
    func stepsDerivedFromFiles(in folderURL: URL, slug: String) -> Set<String> {
        var done: Set<String> = []
        let files = (try? fileManager.contentsOfDirectory(atPath: folderURL.path)) ?? []

        let recordings = folderURL.appendingPathComponent("Recordings")
        if let rec = try? fileManager.contentsOfDirectory(atPath: recordings.path), !rec.isEmpty {
            done.insert("ingest")
        }
        if files.contains(where: { $0.lowercased().hasSuffix(".m4a") }) {
            done.insert("ingest")
            done.insert("reaper")
        }
        if files.contains("\(slug).transcript.txt") { done.insert("transcribe") }
        if files.contains("\(slug).md") { done.insert("shownotes") }
        if files.contains("\(slug).social.md") { done.insert("social") }
        if files.contains("content-\(slug).md") { done.insert("seo") }
        return done
    }

    /// Locates the episode's state file: prefers `<slug>.state.yml`, falls back
    /// to any existing `*.state.yml` or a plain `state.yml` in the folder.
    func stateFileURL(in folderURL: URL, slug: String) -> URL? {
        let preferred = folderURL.appendingPathComponent("\(slug).state.yml")
        if fileManager.fileExists(atPath: preferred.path) { return preferred }

        guard let files = try? fileManager.contentsOfDirectory(atPath: folderURL.path) else { return nil }
        let match = files.sorted().first {
            $0 == "state.yml" || $0.hasSuffix(".state.yml")
        }
        return match.map { folderURL.appendingPathComponent($0) }
    }

    func writeAppMetadata(_ metadata: AppMetadata, to folderURL: URL) throws {
        let url = folderURL.appendingPathComponent(Self.appMetadataFileName)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(metadata).write(to: url)
    }

    func readAppMetadata(from folderURL: URL) -> AppMetadata {
        let url = folderURL.appendingPathComponent(Self.appMetadataFileName)
        guard let data = try? Data(contentsOf: url),
              let meta = try? JSONDecoder().decode(AppMetadata.self, from: data) else {
            return AppMetadata()
        }
        return meta
    }

    /// Finished edited audio present? (mp3 + m4a, task 7.4)
    func hasFinishedAudio(in folderURL: URL) -> Bool {
        guard let files = try? fileManager.contentsOfDirectory(atPath: folderURL.path) else { return false }
        let hasMp3 = files.contains { $0.lowercased().hasSuffix(".mp3") }
        let hasM4a = files.contains { $0.lowercased().hasSuffix(".m4a") }
        return hasMp3 && hasM4a
    }
}
