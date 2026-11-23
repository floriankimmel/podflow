import XCTest
@testable import Podflow

/// The review of one episode, against a real episode folder.
@MainActor
final class ReviewSessionTests: XCTestCase {
    private var root: URL!
    private var store: EpisodeStore!
    private var folder: URL!
    /// Monday 2026-11-23 12:00 local time.
    private let monday = Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 23, hour: 12))!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("podflow-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        store = EpisodeStore(root: root.appendingPathComponent("Podflow"))
        folder = try store.create(number: "7", title: "T", type: .compilation, video: try file("v.mp4"), transcript: nil)
        try write("# Titel", to: EpisodeFile.shownotes)
        try write("## Discord\nKurz\n\n## Instagram\nLang", to: EpisodeFile.social)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    private func file(_ name: String) throws -> URL {
        let url = root.appendingPathComponent(name)
        try "x".write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func write(_ text: String, to name: String) throws {
        try text.write(to: folder.appendingPathComponent(name), atomically: true, encoding: .utf8)
    }

    private func session() -> ReviewSession {
        ReviewSession(folder: folder, store: store, releaseTime: "09:00", now: { self.monday })
    }

    private func onDisk() -> ReviewDraft { store.loadReviewDraft(in: folder) }

    func testEditsInReviewAreSavedRightAway() {
        let review = session()
        review.draft.shownotes = "Geändert"
        review.draft.posts[1].text = "Neu"

        XCTAssertEqual(onDisk().shownotes, "Geändert")
        XCTAssertEqual(onDisk().posts[1].text, "Neu")
        XCTAssertNil(review.saveError)
    }

    func testTextsAreNotSavedWhileARunIsGoingOrAfterReview() {
        let review = session()
        review.runStatus = .init(phase: .review, isRunning: true, anyRunActive: true)
        review.draft.shownotes = "Während des Laufs"
        XCTAssertEqual(onDisk().shownotes, "# Titel")

        let published = session()
        published.runStatus = .init(phase: .publishing)
        published.draft.shownotes = "Nach dem Review"
        XCTAssertEqual(onDisk().shownotes, "# Titel")
        XCTAssertFalse(published.isEditable)
    }

    func testSocialPostsStayEditableAfterPublishing() {
        let review = session()
        review.runStatus = .init(phase: .scheduled)
        XCTAssertTrue(review.canEditPosts)
        review.draft.posts[1].text = "Nach dem Veröffentlichen angepasst"
        XCTAssertEqual(onDisk().posts[1].text, "Nach dem Veröffentlichen angepasst")

        review.runStatus = .init(phase: .publishing, isRunning: true, anyRunActive: true)
        XCTAssertFalse(review.canEditPosts)
    }

    func testRunEndRereadsWhatTheRunWroteWithoutOverwritingIt() throws {
        let review = session()
        review.runStatus = .init(phase: .review, isRunning: true, anyRunActive: true)
        try write("# Vom Lauf", to: EpisodeFile.shownotes)

        review.runStatus = .init(phase: .review)

        XCTAssertEqual(review.draft.shownotes, "# Vom Lauf")
        XCTAssertEqual(onDisk().shownotes, "# Vom Lauf")
    }

    func testReleaseDateIsNextFridayUntilPickedAndThenSurvivesReopening() {
        let review = session()
        let friday = ReviewSession.suggestedReleaseDate(time: "09:00", now: monday)
        XCTAssertEqual(review.releaseDate, friday)
        XCTAssertNil(onDisk().releaseDate, "a suggestion is not a decision")

        let picked = friday.addingTimeInterval(7 * 24 * 3600)
        review.releaseDate = picked

        XCTAssertEqual(session().releaseDate, picked)
    }

    func testReleaseDateCanStillChangeWhenResumingAPublish() {
        let review = session()
        review.runStatus = .init(phase: .publishing)
        let picked = monday.addingTimeInterval(3 * 24 * 3600)
        review.releaseDate = picked

        XCTAssertEqual(session().releaseDate, picked)
    }

    func testPickedImagesKeepUnsavedNothingAndUnlockPublishing() throws {
        let review = session()
        XCTAssertFalse(review.canPublish)
        XCTAssertEqual(review.publishHint, "Bitte zuerst beide Bilder auswählen.")
        XCTAssertNil(review.publishDecisions())

        review.pickImage(try file("a.png"), as: .cover)
        review.pickImage(try file("b.jpg"), as: .featured)

        XCTAssertEqual(onDisk().coverFile, "cover.png")
        XCTAssertEqual(session().draft.featuredFile, "wordpress.jpg")
        XCTAssertTrue(review.canPublish)
        let decisions = try XCTUnwrap(review.publishDecisions())
        XCTAssertEqual(decisions.coverFile, "cover.png")
        XCTAssertEqual(decisions.featuredFile, "wordpress.jpg")
        XCTAssertEqual(decisions.releaseDate, review.releaseDate)
    }

    func testAnotherRunBlocksPublishing() throws {
        let review = session()
        review.pickImage(try file("a.png"), as: .cover)
        review.pickImage(try file("b.png"), as: .featured)
        review.runStatus = .init(phase: .review, isRunning: false, anyRunActive: true)

        XCTAssertFalse(review.canPublish)
        XCTAssertEqual(review.publishHint, "Gerade läuft eine andere Episode.")
        XCTAssertNil(review.publishDecisions())
    }
}
