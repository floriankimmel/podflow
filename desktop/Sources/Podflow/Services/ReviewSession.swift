import Foundation

/// The review of one episode: what is shown and edited, when edits are saved,
/// the picked images and release date, and whether publishing can start.
/// Views only bind to it; everything is read from and written to the episode
/// folder through `EpisodeStore`.
@MainActor
final class ReviewSession: ObservableObject {
    /// What the review needs to know about runs; set by the view.
    struct RunStatus: Equatable {
        var phase: EpisodePhase = .review
        /// A run of this episode is going.
        var isRunning = false
        /// Any run is going (only one at a time).
        var anyRunActive = false
    }

    @Published var draft = ReviewDraft() {
        didSet { autosave() }
    }
    @Published private(set) var saveError: String?
    @Published var runStatus = RunStatus() {
        didSet { if oldValue.isRunning && !runStatus.isRunning { load() } }
    }

    let folder: URL
    private let store: EpisodeStore
    private let releaseTime: String
    private let now: () -> Date
    /// The draft as last read from or written to disk; edits differ from it.
    private var saved = ReviewDraft()

    init(folder: URL, store: EpisodeStore, releaseTime: String, now: @escaping () -> Date = Date.init) {
        self.folder = folder
        self.store = store
        self.releaseTime = releaseTime
        self.now = now
        load()
    }

    /// Shownotes can change only while the episode waits for review and
    /// nothing runs for it: publishing puts them on WordPress.
    var isEditable: Bool { runStatus.phase == .review && !runStatus.isRunning }

    /// Social posts are copied by hand, usually after publishing, so they stay
    /// editable except while a run is going.
    var canEditPosts: Bool { !runStatus.isRunning }

    /// The picked release date, else next Friday at the configured time.
    var releaseDate: Date {
        get { draft.releaseDate ?? Self.suggestedReleaseDate(time: releaseTime, now: now()) }
        set { draft.releaseDate = newValue }
    }

    var canPublish: Bool { draft.hasImages && !runStatus.anyRunActive }

    var publishHint: String {
        if !draft.hasImages { return "Bitte zuerst beide Bilder auswählen." }
        if runStatus.anyRunActive { return "Gerade läuft eine andere Episode." }
        return "Das Video geht auf YouTube, das Audio auf den Server und der Beitrag wird in WordPress für den gewählten Termin geplant."
    }

    /// Rereads the folder, e.g. after a run rewrote the generated files.
    func load() {
        let loaded = store.loadReviewDraft(in: folder)
        saved = loaded
        draft = loaded
    }

    /// Copies a picked image into the folder; it is saved right away.
    func pickImage(_ url: URL, as slot: EpisodeStore.ImageSlot) {
        do {
            let name = try store.storeImage(url, as: slot, in: folder)
            // Already on disk: update the snapshot first so autosave skips it.
            switch slot {
            case .cover: saved.coverFile = name; draft.coverFile = name
            case .featured: saved.featuredFile = name; draft.featuredFile = name
            }
            saveError = nil
        } catch {
            saveError = "Bild konnte nicht übernommen werden: \(error.localizedDescription)"
        }
    }

    /// The decisions the publish run needs, or nil while publishing is blocked.
    func publishDecisions() -> EpisodePipeline.Review? {
        guard canPublish, let coverFile = draft.coverFile, let featuredFile = draft.featuredFile else { return nil }
        return EpisodePipeline.Review(releaseDate: releaseDate, coverFile: coverFile, featuredFile: featuredFile)
    }

    /// Writes the draft whenever it differs from what is on disk, never while
    /// a run is going. Shownotes only during review, the release date until
    /// the episode is scheduled, social posts always.
    private func autosave() {
        guard draft != saved, !runStatus.isRunning else { return }
        var toSave = draft
        if !isEditable { toSave.shownotes = saved.shownotes }
        if runStatus.phase == .scheduled { toSave.releaseDate = saved.releaseDate }
        guard toSave != saved else { return }
        do {
            try store.saveReviewDraft(toSave, in: folder)
            saved = toSave
            saveError = nil
        } catch {
            saveError = "Speichern fehlgeschlagen: \(error.localizedDescription)"
        }
    }

    /// Next Friday at the configured time (the podcast's release slot).
    nonisolated static func suggestedReleaseDate(time: String, now: Date = Date(), calendar: Calendar = .current) -> Date {
        let parts = time.split(separator: ":").compactMap { Int($0) }
        var components = DateComponents()
        components.weekday = 6
        components.hour = parts.first ?? 9
        components.minute = parts.count > 1 ? parts[1] : 0
        return calendar.nextDate(after: now, matching: components, matchingPolicy: .nextTime) ?? now
    }
}
