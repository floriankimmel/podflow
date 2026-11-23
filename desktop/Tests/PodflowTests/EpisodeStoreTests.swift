import XCTest
@testable import Podflow

final class EpisodeStoreTests: XCTestCase {
    private var root: URL!
    private var store: EpisodeStore!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("podflow-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        store = EpisodeStore(root: root.appendingPathComponent("Podflow"))
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    private func file(_ name: String, _ content: String = "x") throws -> URL {
        let url = root.appendingPathComponent(name)
        try content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    func testCreateZencastrEpisodeCopiesTranscriptAndWritesState() throws {
        let video = try file("final.mp4")
        let transcript = try file("zencastr.txt", "Hallo zusammen")

        let folder = try store.create(number: "371", title: "Über den Großglockner", type: .zencastr, video: video, transcript: transcript)

        XCTAssertEqual(folder.lastPathComponent, "371")
        XCTAssertEqual(try String(contentsOf: folder.appendingPathComponent(EpisodeFile.transcript), encoding: .utf8), "Hallo zusammen")
        let state = try XCTUnwrap(store.readState(in: folder))
        XCTAssertEqual(state.type, .zencastr)
        XCTAssertEqual(state.audioBasename, "371_ueber-den-grossglockner")
        XCTAssertEqual(state.video, video.path)
        XCTAssertEqual(state.phase, .notStarted)
    }

    func testInterviewEpisodeNeedsNoTranscript() throws {
        let folder = try store.create(number: "372", title: "Interview", type: .compilation, video: try file("v.mp4"), transcript: nil)
        XCTAssertFalse(FileManager.default.fileExists(atPath: folder.appendingPathComponent(EpisodeFile.transcript).path))
    }

    func testZencastrWithoutTranscriptIsRefused() throws {
        XCTAssertThrowsError(try store.create(number: "373", title: "T", type: .zencastr, video: try file("v.mp4"), transcript: nil)) {
            XCTAssertEqual($0 as? EpisodeStore.StoreError, .missingTranscript)
        }
        XCTAssertTrue(store.listEpisodes().isEmpty)
    }

    func testMissingVideoAndDuplicateAreRefused() throws {
        XCTAssertThrowsError(try store.create(number: "1", title: "T", type: .compilation, video: nil, transcript: nil)) {
            XCTAssertEqual($0 as? EpisodeStore.StoreError, .missingVideo)
        }
        let video = try file("v.mp4")
        try store.create(number: "1", title: "T", type: .compilation, video: video, transcript: nil)
        XCTAssertThrowsError(try store.create(number: "1", title: "T", type: .compilation, video: video, transcript: nil)) {
            XCTAssertEqual($0 as? EpisodeStore.StoreError, .exists("1"))
        }
    }

    func testStateWrittenByPluginIsDecoded() throws {
        let folder = try store.create(number: "5", title: "T", type: .compilation, video: try file("v.mp4"), transcript: nil)
        // Shape written by plugin/skills/episode/scripts/state.sh.
        let json = """
        {"number":"5","title":"T","type":"compilation","audioBasename":"5_t","video":"/v.mp4","steps":{
          "auphonic_create":{"status":"done","updatedAt":"2026-11-23T10:00:00Z","data":{"uuid":"U1"}},
          "auphonic_wait":{"status":"failed","error":"Auphonic: Error","updatedAt":"x"},
          "auphonic_publish":{"data":{"youtubeUrl":"https://youtu.be/abc"}}
        }}
        """
        try json.write(to: folder.appendingPathComponent(EpisodeFile.state), atomically: true, encoding: .utf8)

        let state = try XCTUnwrap(store.readState(in: folder))
        XCTAssertEqual(state.status(of: "auphonic_create"), .done)
        XCTAssertEqual(state.status(of: "transcript"), .pending)
        XCTAssertEqual(state.failedStep?.id, "auphonic_wait")
        XCTAssertEqual(state.failedStep?.error, "Auphonic: Error")
        XCTAssertEqual(state.youtubeURL, "https://youtu.be/abc")
        XCTAssertEqual(state.phase, .preparing)
    }

    func testPhases() {
        var state = EpisodeState(number: "1", title: "T", type: .compilation, audioBasename: "1_t", video: "/v")
        XCTAssertEqual(state.phase, .notStarted)
        state.steps["review"] = .init(status: .inProgress)
        XCTAssertEqual(state.phase, .review)
        state.steps["review"] = .init(status: .done)
        XCTAssertEqual(state.phase, .publishing)
        state.steps["scheduled"] = .init(status: .done)
        XCTAssertEqual(state.phase, .scheduled)
    }

    func testPhaseOfBackendOnlyEpisodeComesFromReportedSteps() {
        var episode = Episode(id: "400")
        XCTAssertEqual(episode.phase, .notStarted)
        episode.backendSteps = [StepStatus(step: StepID.auphonicWait, status: .inProgress)]
        XCTAssertEqual(episode.phase, .preparing)
        XCTAssertTrue(episode.hasStepInProgress)
        episode.backendSteps = [StepStatus(step: StepID.review, status: .inProgress)]
        XCTAssertEqual(episode.phase, .review)
        XCTAssertFalse(episode.hasStepInProgress, "waiting for the person is not a running step")
    }

    // MARK: Review draft

    private func episodeWithGeneratedFiles() throws -> URL {
        let folder = try store.create(number: "9", title: "T", type: .compilation, video: try file("v.mp4"), transcript: nil)
        try "# Titel\n\nText".write(to: folder.appendingPathComponent("shownotes.md"), atomically: true, encoding: .utf8)
        try "## Discord\nKurz\n\n## Instagram\nLang #laufen\n".write(to: folder.appendingPathComponent("social.md"), atomically: true, encoding: .utf8)
        try "**Title Tag:**\nTitel\n\n**Meta-Description:**\nBeschreibung\n".write(to: folder.appendingPathComponent("seo.md"), atomically: true, encoding: .utf8)
        try "# Faktencheck".write(to: folder.appendingPathComponent("factcheck.md"), atomically: true, encoding: .utf8)
        return folder
    }

    func testLoadReviewDraftReadsGeneratedFiles() throws {
        let draft = store.loadReviewDraft(in: try episodeWithGeneratedFiles())

        XCTAssertEqual(draft.shownotes, "# Titel\n\nText")
        XCTAssertEqual(draft.posts, [SocialPost(platform: "Discord", text: "Kurz"), SocialPost(platform: "Instagram", text: "Lang #laufen")])
        XCTAssertEqual(draft.seo.map(\.label), ["Title Tag", "Meta-Description"])
        XCTAssertEqual(draft.seo.map(\.isManual), [true, false])
        XCTAssertEqual(draft.factcheck, "# Faktencheck")
        XCTAssertFalse(draft.hasImages)
    }

    func testSavedEditsAreWhatALaterLoadReturns() throws {
        let folder = try episodeWithGeneratedFiles()
        var draft = store.loadReviewDraft(in: folder)
        draft.shownotes = "Geändert"
        draft.posts[1].text = "Neu"

        try store.saveReviewDraft(draft, in: folder)

        XCTAssertEqual(store.loadReviewDraft(in: folder), draft)
    }

    func testEmptyPostListDoesNotWipeSocialFile() throws {
        let folder = try episodeWithGeneratedFiles()
        var draft = store.loadReviewDraft(in: folder)
        draft.posts = []

        try store.saveReviewDraft(draft, in: folder)

        XCTAssertEqual(store.loadReviewDraft(in: folder).posts.count, 2)
    }

    func testEpisodeWithoutGeneratedFilesGivesEmptyDraft() throws {
        let folder = try store.create(number: "8", title: "T", type: .compilation, video: try file("v.mp4"), transcript: nil)
        XCTAssertEqual(store.loadReviewDraft(in: folder), ReviewDraft())
    }

    func testPickedImagesShowUpInDraftAndReplaceEarlierPick() throws {
        let folder = try episodeWithGeneratedFiles()
        XCTAssertEqual(try store.storeImage(try file("a.PNG"), as: .cover, in: folder), "cover.png")
        XCTAssertEqual(try store.storeImage(try file("b.jpg"), as: .cover, in: folder), "cover.jpg")
        XCTAssertEqual(store.loadReviewDraft(in: folder).coverFile, "cover.jpg")
        XCTAssertFalse(store.loadReviewDraft(in: folder).hasImages)

        try store.storeImage(try file("c.png"), as: .featured, in: folder)
        let draft = store.loadReviewDraft(in: folder)
        XCTAssertEqual(draft.featuredFile, "wordpress.png")
        XCTAssertTrue(draft.hasImages)
    }

    func testRePickingTheCurrentImageKeepsIt() throws {
        let folder = try episodeWithGeneratedFiles()
        try store.storeImage(try file("a.png", "bild"), as: .cover, in: folder)
        let current = folder.appendingPathComponent("cover.png")

        XCTAssertEqual(try store.storeImage(current, as: .cover, in: folder), "cover.png")

        XCTAssertEqual(try String(contentsOf: current, encoding: .utf8), "bild")
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: folder.path).filter { $0.hasPrefix(".cover") }, [])
    }

    func testFailedImageCopyKeepsTheEarlierPick() throws {
        let folder = try episodeWithGeneratedFiles()
        try store.storeImage(try file("a.png", "bild"), as: .cover, in: folder)

        XCTAssertThrowsError(try store.storeImage(root.appendingPathComponent("weg.jpg"), as: .cover, in: folder))

        XCTAssertEqual(store.loadReviewDraft(in: folder).coverFile, "cover.png")
    }

    /// The seam between app and plugin: what the real `state.sh` writes must
    /// decode into the app's state.
    func testStateWrittenByRealStateScriptIsDecoded() async throws {
        let script = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("plugin/skills/episode/scripts/state.sh").path
        let folder = try store.create(number: "12", title: "Über Trails", type: .compilation, video: try file("v.mp4"), transcript: nil)

        func state(_ arguments: String...) async throws {
            let result = try await ProcessRunner.run("/bin/bash", [script] + arguments, currentDirectory: folder)
            XCTAssertEqual(result.exitCode, 0, result.output)
        }
        try await state("set", StepID.auphonicCreate, "in_progress")
        try await state("put", StepID.auphonicCreate, "uuid", "U1")
        try await state("set", StepID.auphonicCreate, "done")
        try await state("set", StepID.auphonicWait, "failed", "Auphonic: Error")
        try await state("put", StepID.auphonicPublish, StepID.youtubeURLKey, "https://youtu.be/abc")

        let decoded = try XCTUnwrap(store.readState(in: folder))
        XCTAssertEqual(decoded.title, "Über Trails")
        XCTAssertEqual(decoded.status(of: StepID.auphonicCreate), .done)
        XCTAssertEqual(decoded.steps[StepID.auphonicCreate]?.data?["uuid"], "U1")
        XCTAssertEqual(decoded.failedStep?.id, StepID.auphonicWait)
        XCTAssertEqual(decoded.failedStep?.error, "Auphonic: Error")
        XCTAssertEqual(decoded.youtubeURL, "https://youtu.be/abc")
        XCTAssertEqual(decoded.phase, .preparing)
    }

    func testDeleteRemovesEpisodeFromList() throws {
        try store.create(number: "20", title: "Weg", type: .compilation, video: try file("v.mp4"), transcript: nil)
        try store.create(number: "21", title: "Bleibt", type: .compilation, video: try file("v.mp4"), transcript: nil)

        try store.delete(number: "20")

        XCTAssertEqual(store.listEpisodes().map(\.number), ["21"])
        XCTAssertNoThrow(try store.delete(number: "20"), "deleting twice is harmless")
    }

    func testSlugAndNextNumber() {
        XCTAssertEqual(EpisodeStore.slug("  Wien-Marathon 2026: Größer & schöner!  "), "wien-marathon-2026-groesser-schoener")
        XCTAssertEqual(EpisodeStore.slug("Café Olé"), "cafe-ole")
        XCTAssertEqual(EpisodeStore.slug("!!!"), "episode")
        XCTAssertEqual(EpisodeStore.nextNumber(known: ["370", "9", "abc"]), "371")
        XCTAssertEqual(EpisodeStore.nextNumber(known: []), "")
    }
}

final class ContentParserTests: XCTestCase {
    func testSocialRoundTrip() {
        let markdown = """
        ## Discord
        Neue Folge! https://laufendentdecken-podcast.at/371

        ## Instagram
        Zeile eins

        Zeile zwei
        #laufen #podcast
        """
        var posts = ContentParser.socialPosts(from: markdown)
        XCTAssertEqual(posts.map(\.platform), ["Discord", "Instagram"])
        XCTAssertEqual(posts[1].text, "Zeile eins\n\nZeile zwei\n#laufen #podcast")

        posts[0].text = "Geändert"
        let rewritten = ContentParser.socialMarkdown(from: posts)
        XCTAssertEqual(ContentParser.socialPosts(from: rewritten), posts)
    }

    func testSEOSectionsIgnoreCodeFence() {
        let markdown = """
        ```
        **Title Tag:**
        Marathon – Folge 371 | Laufendentdecken Podcast

        **YouTube Beschreibung:**
        Hook.

        - Punkt
        ```
        """
        let sections = ContentParser.seoSections(from: markdown)
        XCTAssertEqual(sections.map(\.label), ["Title Tag", "YouTube Beschreibung"])
        XCTAssertEqual(sections[0].text, "Marathon – Folge 371 | Laufendentdecken Podcast")
        XCTAssertEqual(sections[1].text, "Hook.\n\n- Punkt")
    }
}
