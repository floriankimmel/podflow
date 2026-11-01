import XCTest
@testable import Podflow

/// Stub model runner: returns canned text and records prompts.
final class StubRunner: TextModelRunner, @unchecked Sendable {
    var response: String
    private(set) var prompts: [String] = []
    init(response: String) { self.response = response }
    func run(prompt: String) async throws -> String {
        prompts.append(prompt)
        return response
    }
}

final class GenerationTests: XCTestCase {
    private var tempDir: URL!
    private var promptsDir: URL!

    override func setUp() async throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("gen-tests-\(UUID().uuidString)", isDirectory: true)
        promptsDir = tempDir.appendingPathComponent("prompts", isDirectory: true)
        try FileManager.default.createDirectory(at: promptsDir, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    private func makeEpisode(slug: String = "259_test", transcript: String? = "Hallo Transkript") throws -> URL {
        let folder = tempDir.appendingPathComponent(slug, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        if let transcript {
            try transcript.write(
                to: TranscriptionService.transcriptURL(episodeFolder: folder), atomically: true, encoding: .utf8)
        }
        return folder
    }

    func testPromptSubstitution() {
        let result = PromptStore.substitute(
            "Folge {{episode_number}}: <t>{{transcript}}</t> {{shownotes}} {{text}}",
            values: ["episode_number": "259", "transcript": "T", "shownotes": "S", "text": "X"])
        XCTAssertEqual(result, "Folge 259: <t>T</t> S X")
    }

    func testPromptStoreEditPersistsAndIsUsed() throws {
        let store = PromptStore(directory: promptsDir)
        let original = try store.text(for: .shownotes)
        XCTAssertTrue(original.contains("{{transcript}}"), "bundled prompt loads")
        XCTAssertFalse(store.isEdited(.shownotes))

        try store.save("MEIN PROMPT {{transcript}}", for: .shownotes)
        XCTAssertTrue(store.isEdited(.shownotes))
        // A fresh store (relaunch) sees the edit.
        let reloaded = PromptStore(directory: promptsDir)
        XCTAssertEqual(try reloaded.text(for: .shownotes), "MEIN PROMPT {{transcript}}")

        store.resetToBundled(.shownotes)
        XCTAssertEqual(try store.text(for: .shownotes), original)
    }

    func testShownotesGenerationWritesFileAndUsesEditedPrompt() async throws {
        let folder = try makeEpisode()
        let store = PromptStore(directory: promptsDir)
        try store.save("CUSTOM {{episode_number}} <transcript>{{transcript}}</transcript>", for: .shownotes)
        let runner = StubRunner(response: "# 🎙️ Folge 259")
        let service = GenerationService(runner: runner, prompts: store)

        let result = try await service.generateShownotes(
            episodeFolder: folder, episodeNumber: "259", config: nil)
        XCTAssertEqual(result, "# 🎙️ Folge 259")
        XCTAssertEqual(runner.prompts.count, 1)
        XCTAssertTrue(runner.prompts[0].contains("CUSTOM 259"), "edited prompt is used")
        XCTAssertTrue(runner.prompts[0].contains("Hallo Transkript"))

        let written = try String(
            contentsOf: GenerationService.shownotesURL(episodeFolder: folder, config: nil, episodeNumber: "259"),
            encoding: .utf8)
        XCTAssertEqual(written, "# 🎙️ Folge 259")
    }

    func testShownotesStatefulSkipAndForcedRerun() async throws {
        let folder = try makeEpisode()
        let runner = StubRunner(response: "GENERIERT")
        let service = GenerationService(runner: runner, prompts: PromptStore(directory: promptsDir))

        _ = try await service.generateShownotes(episodeFolder: folder, episodeNumber: "1", config: nil)
        // Manual edit is retained — not overwritten without force (task 4.3).
        let url = GenerationService.shownotesURL(episodeFolder: folder, config: nil, episodeNumber: "1")
        try "EDITIERT".write(to: url, atomically: true, encoding: .utf8)
        let second = try await service.generateShownotes(episodeFolder: folder, episodeNumber: "1", config: nil)
        XCTAssertEqual(second, "EDITIERT", "skip when done keeps the edit")
        XCTAssertEqual(runner.prompts.count, 1)

        let third = try await service.generateShownotes(episodeFolder: folder, episodeNumber: "1", config: nil, force: true)
        XCTAssertEqual(third, "GENERIERT", "forced re-run regenerates")
        XCTAssertEqual(runner.prompts.count, 2)
    }

    func testShownotesFailsWithoutTranscript() async throws {
        let folder = try makeEpisode(transcript: nil)
        let service = GenerationService(runner: StubRunner(response: "x"), prompts: PromptStore(directory: promptsDir))
        do {
            _ = try await service.generateShownotes(episodeFolder: folder, episodeNumber: "1", config: nil)
            XCTFail("must throw without transcript")
        } catch let error as GenerationService.GenerationError {
            guard case .missingTranscript = error else { return XCTFail("wrong error \(error)") }
        }
    }

    func testSocialGenerationProducesAllSixPlatforms() async throws {
        let folder = try makeEpisode()
        let shownotesURL = GenerationService.shownotesURL(episodeFolder: folder, config: nil, episodeNumber: "259")
        try "# Shownotes".write(to: shownotesURL, atomically: true, encoding: .utf8)

        let response = """
        ## Discord
        Neue Folge! https://laufendentdecken-podcast.at/259

        ## LinkedIn
        Langer Post
        #laufen

        ## Instagram
        Insta Post

        ## Strava
        Strava Post

        ## Facebook
        FB Post

        ## YouTube
        YT Post
        """
        let service = GenerationService(runner: StubRunner(response: response), prompts: PromptStore(directory: promptsDir))
        let posts = try await service.generateSocial(episodeFolder: folder, episodeNumber: "259", config: nil)
        XCTAssertEqual(Set(posts.keys), Set(ContentKey.socialPlatforms))
        XCTAssertEqual(posts["discord"], "Neue Folge! https://laufendentdecken-podcast.at/259")
    }

    func testSEOWritesPodflowReadableContentFile() async throws {
        let folder = try makeEpisode(slug: "podflow")
        let config = try PresetStore.parseConfiguration("""
        steps:
          - wordpress:
              server: https://x
              showNotes: "{{folderName}}.md"
              contentFile: "content-{{folderName}}.md"
        """)
        try "# Notes".write(
            to: GenerationService.shownotesURL(episodeFolder: folder, config: config, episodeNumber: "259"),
            atomically: true, encoding: .utf8)
        let response = """
        **Title Tag:**
        Marathon Training – Folge 259 | Laufendentdecken Podcast

        **Meta-Description:**
        Alles über Marathontraining. Jetzt anhören!

        **Focus Keywords:**
        marathon, training, laufen

        **YouTube Titel:**
        Marathon Training erklärt

        **YouTube Beschreibung:**
        Hook hier.
        Punkte hier. https://laufendentdecken-podcast.at/259

        **YouTube Tags:**
        marathon, laufen
        """
        let service = GenerationService(runner: StubRunner(response: response), prompts: PromptStore(directory: promptsDir))
        let seo = try await service.generateSEO(episodeFolder: folder, episodeNumber: "259", config: config)

        // File lands at podflow's configured contentFile path with the
        // regex-parsed markers the CLI reads.
        let written = try String(contentsOf: folder.appendingPathComponent("content-podflow.md"), encoding: .utf8)
        XCTAssertTrue(written.contains("**Meta-Description:**"))
        XCTAssertTrue(written.contains("**Focus Keywords:**"))
        XCTAssertEqual(written, seo)

        // YouTube description extraction (video profile → Auphonic metadata).
        let description = GenerationService.youtubeDescription(fromSEO: seo)
        XCTAssertEqual(description, "Hook hier.\nPunkte hier. https://laufendentdecken-podcast.at/259")
    }

    func testShownotesPathUsesConfiguredWordpressPath() throws {
        let config = try PresetStore.parseConfiguration("""
        steps:
          - wordpress:
              showNotes: "{{folderName}}.md"
        """)
        let folder = URL(fileURLWithPath: "/tmp/259_marathon")
        let url = GenerationService.shownotesURL(episodeFolder: folder, config: config, episodeNumber: "259")
        XCTAssertEqual(url.lastPathComponent, "259_marathon.md")
    }
}
