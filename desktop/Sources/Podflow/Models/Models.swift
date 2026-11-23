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
}

// MARK: - Episode type

/// How the episode was made, which decides where the transcript comes from.
/// Everything else in the flow is identical.
enum EpisodeType: String, Codable, CaseIterable, Identifiable, Sendable {
    /// Zencastr recording: transcript exported from Zencastr, supplied when the episode is created.
    case zencastr
    /// Interview compilation: transcript from Auphonic speech recognition.
    case compilation

    var id: String { rawValue }

    var label: String {
        switch self {
        case .zencastr: return "Zencastr-Aufnahme"
        case .compilation: return "Interview-Zusammenschnitt"
        }
    }

    var hint: String {
        switch self {
        case .zencastr: return "Das Transkript kommt aus Zencastr."
        case .compilation: return "Auphonic erstellt das Transkript."
        }
    }
}

// MARK: - Pipeline

/// Which headless run a stage belongs to.
enum RunMode: String, Sendable {
    case prepare
    case publish
}

/// Step ids the plugin writes to `state.json` and reports to the backend
/// (`plugin/skills/episode/SKILL.md`). The only place they are spelled out.
enum StepID {
    static let auphonicCreate = "auphonic_create"
    static let auphonicUpload = "auphonic_upload"
    static let auphonicStart = "auphonic_start"
    static let auphonicWait = "auphonic_wait"
    static let transcript = "transcript"
    static let generateShownotes = "generate_shownotes"
    static let generateSEO = "generate_seo"
    static let generateSocial = "generate_social"
    static let factcheck = "factcheck"
    static let review = "review"
    static let auphonicMetadata = "auphonic_metadata"
    static let auphonicCover = "auphonic_cover"
    static let auphonicPublish = "auphonic_publish"
    static let shownotesYoutubeLink = "shownotes_youtube_link"
    static let wordpress = "wordpress"
    static let scheduled = "scheduled"

    /// Key under which `auphonic_publish` stores the YouTube URL.
    static let youtubeURLKey = "youtubeUrl"
}

struct PipelineStage: Identifiable, Hashable, Sendable {
    let id: String
    let label: String
    let systemImage: String
    /// The stage is done by the person in the app, not by a run.
    var waitsForUser = false

    static let all: [PipelineStage] = [
        PipelineStage(id: StepID.auphonicCreate, label: "Auphonic vorbereiten", systemImage: "waveform.badge.plus"),
        PipelineStage(id: StepID.auphonicUpload, label: "Video hochladen", systemImage: "arrow.up.circle"),
        PipelineStage(id: StepID.auphonicStart, label: "Auphonic starten", systemImage: "play.circle"),
        PipelineStage(id: StepID.auphonicWait, label: "Auphonic verarbeitet", systemImage: "waveform"),
        PipelineStage(id: StepID.transcript, label: "Transkript", systemImage: "text.quote"),
        PipelineStage(id: StepID.generateShownotes, label: "Shownotes", systemImage: "doc.text"),
        PipelineStage(id: StepID.generateSEO, label: "SEO", systemImage: "magnifyingglass"),
        PipelineStage(id: StepID.generateSocial, label: "Social Media", systemImage: "megaphone"),
        PipelineStage(id: StepID.factcheck, label: "Faktencheck", systemImage: "checkmark.seal"),
        PipelineStage(id: StepID.review, label: "Prüfen", systemImage: "eye", waitsForUser: true),
        PipelineStage(id: StepID.auphonicMetadata, label: "YouTube-Texte setzen", systemImage: "text.badge.checkmark"),
        PipelineStage(id: StepID.auphonicCover, label: "Cover übergeben", systemImage: "photo"),
        PipelineStage(id: StepID.auphonicPublish, label: "YouTube & Audio veröffentlichen", systemImage: "play.rectangle"),
        PipelineStage(id: StepID.shownotesYoutubeLink, label: "YouTube-Link einfügen", systemImage: "link"),
        PipelineStage(id: StepID.wordpress, label: "WordPress planen", systemImage: "globe"),
        PipelineStage(id: StepID.scheduled, label: "Geplant", systemImage: "calendar.badge.checkmark"),
    ]

    static func label(for id: String) -> String {
        all.first { $0.id == id }?.label ?? id
    }
}

/// Coarse position of an episode in the flow, derived from step statuses.
/// Views decide what to show from this, never from step ids.
enum EpisodePhase: Equatable, Sendable {
    case notStarted
    case preparing
    case review
    case publishing
    /// Handed over to YouTube, feed and website; waiting for the release date.
    case scheduled

    static func derive(started: Bool, status: (String) -> StepState) -> EpisodePhase {
        if status(StepID.scheduled) == .done { return .scheduled }
        if status(StepID.review) == .done { return .publishing }
        if status(StepID.review) == .inProgress { return .review }
        return started ? .preparing : .notStarted
    }
}

// MARK: - Local episode state (state.json)

/// The plugin's `state.json` in the episode folder. The app creates it and
/// reads it; step entries are written by the plugin's `state.sh`.
struct EpisodeState: Codable, Equatable, Sendable {
    struct Step: Codable, Equatable, Sendable {
        var status: StepState?
        var error: String?
        var data: [String: String]?
        var updatedAt: String?

        init(status: StepState? = nil, error: String? = nil, data: [String: String]? = nil, updatedAt: String? = nil) {
            self.status = status
            self.error = error
            self.data = data
            self.updatedAt = updatedAt
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            status = (try container.decodeIfPresent(String.self, forKey: .status)).flatMap(StepState.init(rawValue:))
            error = try container.decodeIfPresent(String.self, forKey: .error)
            data = try container.decodeIfPresent([String: String].self, forKey: .data)
            updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt)
        }
    }

    var number: String
    var title: String
    var type: EpisodeType
    /// Base name of the audio file on the podcast server; also the Podlove slug.
    var audioBasename: String
    /// Absolute path of the finished video.
    var video: String
    var steps: [String: Step] = [:]

    func status(of step: String) -> StepState {
        steps[step]?.status ?? .pending
    }

    var failedStep: (id: String, error: String)? {
        for stage in PipelineStage.all {
            if let step = steps[stage.id], step.status == .failed {
                return (stage.id, step.error ?? "")
            }
        }
        return nil
    }

    var youtubeURL: String? {
        steps[StepID.auphonicPublish]?.data?[StepID.youtubeURLKey]
    }

    var phase: EpisodePhase {
        EpisodePhase.derive(started: !steps.isEmpty, status: status(of:))
    }
}

// MARK: - Episode (sidebar row)

/// A local episode folder, a backend record, or both merged by episode number.
struct Episode: Identifiable, Equatable, Sendable {
    var id: String
    var folderURL: URL?
    var state: EpisodeState?
    var backendTitle: String?
    var backendSteps: [StepStatus] = []

    var number: String { state?.number ?? id }
    var title: String {
        if let title = state?.title, !title.isEmpty { return title }
        return backendTitle ?? ""
    }
    var isLocal: Bool { folderURL != nil }

    /// Local state wins; backend status is the fallback (co-host's episodes).
    func status(of step: String) -> StepState {
        if let state { return state.status(of: step) }
        return backendSteps.first { $0.step == step }?.status ?? .pending
    }

    var phase: EpisodePhase {
        if let state { return state.phase }
        return EpisodePhase.derive(started: !backendSteps.isEmpty, status: status(of:))
    }

    var hasFailure: Bool {
        PipelineStage.all.contains { status(of: $0.id) == .failed }
    }

    /// A run step is marked in progress (here or on the other Mac).
    var hasStepInProgress: Bool {
        PipelineStage.all.contains { !$0.waitsForUser && status(of: $0.id) == .inProgress }
    }
}

// MARK: - Episode files

enum EpisodeFile {
    static let state = "state.json"
    static let transcript = "transcript.txt"
    static let shownotes = "shownotes.md"
    static let social = "social.md"
    static let seo = "seo.md"
    static let factcheck = "factcheck.md"
    static let chapters = "chapters.txt"
    static let runLog = "run.log"
    static let coverBase = "cover"
    static let featuredBase = "wordpress"
}

/// One platform block of `social.md` ("## Instagram" …).
struct SocialPost: Identifiable, Equatable, Sendable {
    var platform: String
    var text: String
    var id: String { platform }
}

/// One labelled section of `seo.md` ("**Title Tag:**" …).
struct SEOSection: Identifiable, Equatable, Sendable {
    var label: String
    var text: String
    var id: String { label }

    /// The publish run cannot set this section; it is pasted into WordPress by hand.
    var isManual: Bool {
        ["Title Tag", "Facebook OG Title", "Facebook OG Description"].contains(label)
    }
}

/// Everything the review step shows and edits for one episode.
struct ReviewDraft: Equatable, Sendable {
    var shownotes = ""
    var posts: [SocialPost] = []
    var seo: [SEOSection] = []
    var factcheck = ""
    /// File names inside the episode folder, nil until picked.
    var coverFile: String?
    var featuredFile: String?

    var hasImages: Bool { coverFile != nil && featuredFile != nil }
}
