import Foundation

// MARK: - Step status

enum StepState: String, Codable, CaseIterable, Sendable {
    case pending
    case inProgress = "in_progress"
    case done
    case failed
}

struct StepStatus: Codable, Hashable, Sendable {
    var step: String
    var status: StepState
    var updatedAt: String

    enum CodingKeys: String, CodingKey {
        case step, status, updatedAt
    }

    init(step: String, status: StepState, updatedAt: String = "") {
        self.step = step
        self.status = status
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        step = try container.decode(String.self, forKey: .step)
        let raw = try container.decode(String.self, forKey: .status)
        status = StepState(rawValue: raw) ?? .pending
        updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt) ?? ""
    }
}

// MARK: - Backend episode record

struct BackendEpisode: Codable, Identifiable, Sendable {
    var id: String
    var episodeNumber: String?
    var slug: String?
    var title: String?
    var releaseDate: String?
    var profile: String?
    var steps: [StepStatus]
    var content: [String: String]?
    var updatedAt: String?

    func status(of step: String) -> StepState {
        steps.first(where: { $0.step == step })?.status ?? .pending
    }

    var anyStepInProgress: Bool {
        steps.contains { $0.status == .inProgress }
    }
}

// MARK: - Episode profile

/// A profile selects the ordered pipeline stages an episode moves through and
/// which podflow publish steps run (design D11).
struct EpisodeProfile: Identifiable, Hashable, Sendable {
    let id: String
    let displayName: String
    /// Ordered stage keys rendered by the flow visualization.
    let stages: [Stage]
    /// Publish step keys excluded for this profile (e.g. auphonic for video).
    let excludedPublishSteps: Set<String>

    struct Stage: Hashable, Sendable {
        let key: String
        let label: String
        let systemImage: String
    }

    static let publishStages: [Stage] = [
        Stage(key: "ftp_upload", label: "FTP Upload", systemImage: "arrow.up.circle"),
        Stage(key: "download", label: "Download", systemImage: "arrow.down.circle"),
        Stage(key: "s3", label: "S3", systemImage: "externaldrive.badge.icloud"),
        Stage(key: "wordpress", label: "WordPress", systemImage: "globe"),
        Stage(key: "steady", label: "Steady", systemImage: "heart.circle"),
        Stage(key: "auphonic", label: "Auphonic", systemImage: "waveform.badge.magnifyingglass"),
    ]

    static let contentStages: [Stage] = [
        Stage(key: "transcribe", label: "Transkript", systemImage: "text.quote"),
        Stage(key: "shownotes", label: "Shownotes", systemImage: "doc.text"),
        Stage(key: "social", label: "Social", systemImage: "megaphone"),
        Stage(key: "seo", label: "SEO", systemImage: "magnifyingglass"),
    ]

    static let studio = EpisodeProfile(
        id: "studio",
        displayName: "Studio / Reaper",
        stages: [
            Stage(key: "ingest", label: "Ingest", systemImage: "tray.and.arrow.down"),
            Stage(key: "reaper", label: "Reaper", systemImage: "scissors"),
        ] + contentStages + publishStages,
        excludedPublishSteps: []
    )

    static let video = EpisodeProfile(
        id: "video",
        displayName: "Video / Auphonic",
        stages: [
            Stage(key: "video", label: "Video", systemImage: "video"),
            Stage(key: "auphonic_production", label: "Auphonic", systemImage: "waveform.badge.magnifyingglass"),
            Stage(key: "download_audio", label: "Audio laden", systemImage: "arrow.down.circle"),
        ] + contentStages + publishStages.filter { $0.key != "auphonic" },
        // Auphonic already ran up front for this profile; publish must skip it.
        excludedPublishSteps: ["auphonic"]
    )

    /// Stages limited to the publish steps the preset config actually has:
    /// non-publish stages always stay; publish stages missing from the config
    /// are hidden. nil config shows everything.
    func stages(configuredPublish: Set<String>?) -> [Stage] {
        guard let configuredPublish else { return stages }
        let publishKeys = Set(Self.publishStages.map(\.key))
        return stages.filter { !publishKeys.contains($0.key) || configuredPublish.contains($0.key) }
    }

    static let all: [EpisodeProfile] = [.studio, .video]

    static func named(_ id: String?) -> EpisodeProfile {
        all.first { $0.id == id } ?? .studio
    }
}

// MARK: - Local episode (folder on disk)

struct LocalEpisode: Identifiable, Hashable, Sendable {
    var id: String { folderURL.path }
    let folderURL: URL
    var slug: String { folderURL.lastPathComponent }
    var episodeNumber: String?
    var title: String?
    var releaseDate: String?
    var profileID: String?
    var presetID: String?
    /// Stage keys marked done by the CLI's local state.yml flags.
    var doneSteps: Set<String> = []

    /// Backend identity: episode number once assigned, slug before that (D3).
    var identity: String { episodeNumber ?? slug }
}

/// One row in the sidebar: a local folder, a backend record, or both merged.
struct Episode: Identifiable, Hashable, Sendable {
    var id: String
    var local: LocalEpisode?
    var backendID: String?
    var episodeNumber: String?
    var title: String?
    var releaseDate: String?
    var profileID: String?

    var profile: EpisodeProfile { EpisodeProfile.named(profileID) }

    var displayTitle: String {
        if let title, !title.isEmpty { return title }
        return local?.slug ?? id
    }

    var displayNumber: String? {
        if let episodeNumber, !episodeNumber.isEmpty { return episodeNumber }
        return nil
    }
}

// MARK: - Content keys

enum ContentKey {
    static let transcript = "transcript"
    static let shownotes = "shownotes"
    static let seo = "seo"
    static let socialPlatforms = ["discord", "linkedin", "instagram", "strava", "facebook", "youtube"]
    static func social(_ platform: String) -> String { "social_\(platform)" }
}
