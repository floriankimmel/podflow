import XCTest
import Yams
@testable import Podflow

final class PublishConfigTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("podflow-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root.appendingPathComponent("371"), withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    private var inputs: PublishConfig.Inputs {
        var components = DateComponents()
        (components.year, components.month, components.day, components.hour, components.minute) = (2026, 11, 27, 9, 0)
        return PublishConfig.Inputs(
            number: "371", title: "Großglockner", audioBasename: "371_grossglockner",
            releaseDate: Calendar.current.date(from: components)!,
            coverFile: "cover.png", featuredFile: "wordpress.jpg",
            wordpressServer: "https://example.test", ftpHost: "ftp.example.test", ftpPort: "21",
            posterBaseURL: "http://files.example.test/data")
    }

    func testConfigHasCoverUploadAndWordPressStepWithoutSecrets() throws {
        let yaml = try PublishConfig.configYAML(inputs)
        let config = try XCTUnwrap(try Yams.load(yaml: yaml) as? [String: Any])
        let steps = try XCTUnwrap(config["steps"] as? [[String: Any]])
        XCTAssertEqual(steps.count, 2)

        let ftp = try XCTUnwrap(steps[0]["ftp"] as? [String: Any])
        XCTAssertEqual(ftp["username"] as? String, "{{env.FTP_USER}}")
        XCTAssertEqual(ftp["password"] as? String, "{{env.FTP_PWD}}")
        let upload = try XCTUnwrap((ftp["files"] as? [[String: String]])?.first)
        XCTAssertEqual(upload, ["source": "cover.png", "target": "371_grossglockner.png"])

        let wordpress = try XCTUnwrap(steps[1]["wordpress"] as? [String: Any])
        XCTAssertEqual(wordpress["apiKey"] as? String, "{{env.WP_KEY}}")
        XCTAssertEqual(wordpress["image"] as? String, "wordpress.jpg")
        XCTAssertEqual(wordpress["poster"] as? String, "http://files.example.test/data/371_grossglockner.png")
        XCTAssertEqual(wordpress["episode"] as? String, "371_grossglockner")
        XCTAssertEqual(wordpress["showNotes"] as? String, "shownotes.md")
        XCTAssertEqual(wordpress["contentFile"] as? String, "seo.md")
        XCTAssertEqual(wordpress["chapter"] as? String, "chapters.txt")
    }

    func testWriteCreatesConfigChaptersAndCLIState() throws {
        let folder = root.appendingPathComponent("371")
        let configDirectory = root.appendingPathComponent("config")
        let writer = PublishConfig(configDirectory: configDirectory)

        let fileName = try writer.write(inputs, episodeFolder: folder)

        XCTAssertEqual(fileName, "episode-371.yml")
        XCTAssertTrue(FileManager.default.fileExists(atPath: configDirectory.appendingPathComponent(fileName).path))
        XCTAssertEqual(try String(contentsOf: folder.appendingPathComponent("chapters.txt"), encoding: .utf8), "")
        let state = try XCTUnwrap(
            try Yams.load(yaml: String(contentsOf: folder.appendingPathComponent("371.state.yml"), encoding: .utf8)) as? [String: Any])
        let metadata = try XCTUnwrap(state["metadata"] as? [String: Any])
        XCTAssertEqual(metadata["releaseDate"] as? String, "2026-11-27 09:00:00")
        XCTAssertEqual(metadata["title"] as? String, "Großglockner")
        XCTAssertEqual("\(metadata["episodeNumber"] ?? "")", "371")
    }

    func testCLIProgressSurvivesRewrite() throws {
        let folder = root.appendingPathComponent("371")
        let existing = "ftpUploaded: true\nwordpress:\n  wordpressID: \"4711\"\nmetadata:\n  title: Alt\n"
        try existing.write(to: folder.appendingPathComponent("371.state.yml"), atomically: true, encoding: .utf8)

        try PublishConfig(configDirectory: root.appendingPathComponent("config")).writeCLIState(inputs, episodeFolder: folder)

        let state = try XCTUnwrap(
            try Yams.load(yaml: String(contentsOf: folder.appendingPathComponent("371.state.yml"), encoding: .utf8)) as? [String: Any])
        XCTAssertEqual(state["ftpUploaded"] as? Bool, true)
        XCTAssertEqual("\((state["wordpress"] as? [String: Any])?["wordpressID"] ?? "")", "4711")
        XCTAssertEqual((state["metadata"] as? [String: Any])?["title"] as? String, "Großglockner")
    }
}

final class ClaudeTests: XCTestCase {
    func testLoggedInDetection() {
        XCTAssertTrue(ClaudeSetup.isLoggedIn(authStatusOutput: "{\n \"loggedIn\": true, \"authMethod\": \"claude.ai\"\n}"))
        XCTAssertFalse(ClaudeSetup.isLoggedIn(authStatusOutput: "{\"loggedIn\": false}"))
        XCTAssertFalse(ClaudeSetup.isLoggedIn(authStatusOutput: "Not logged in"))
    }

    func testMissingBinaryIsReported() async {
        let setup = ClaudeSetup(binaryOverride: "/nonexistent/claude")
        let status = await setup.status()
        XCTAssertEqual(status, .missing)
    }

    func testStreamParserProducesReadableLinesAcrossChunks() {
        let parser = StreamParser()
        let assistant = #"{"type":"assistant","message":{"content":[{"type":"text","text":"Starte Auphonic."},{"type":"tool_use","name":"Bash","input":{"command":"bash auphonic.sh start U1","description":"Start production"}}]}}"#
        let result = #"{"type":"result","is_error":false,"result":"Bereit zum Prüfen."}"#

        var lines = parser.feed(String(assistant.prefix(40)))
        XCTAssertTrue(lines.isEmpty)
        lines += parser.feed(String(assistant.dropFirst(40)) + "\n" + #"{"type":"system","subtype":"init"}"# + "\n" + result + "\n")

        XCTAssertEqual(lines, ["Starte Auphonic.", "› Bash: Start production"])
        XCTAssertEqual(parser.summary, "Bereit zum Prüfen.")
        XCTAssertFalse(parser.isError)
    }

    func testStreamParserKeepsNonJSONOutputAndErrorFlag() {
        let parser = StreamParser()
        let lines = parser.feed("Error: not logged in\n" + #"{"type":"result","is_error":true,"result":"kaputt"}"# + "\n")
        XCTAssertEqual(lines, ["Error: not logged in"])
        XCTAssertTrue(parser.isError)
    }

    /// A fake `claude` records how it was called.
    func testRunnerStartsClaudeHeadlessInEpisodeFolder() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("podflow-tests-\(UUID().uuidString)")
        let folder = root.appendingPathComponent("371")
        let plugin = root.appendingPathComponent("plugin")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: plugin, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let fake = root.appendingPathComponent("claude")
        let script = """
        #!/bin/bash
        printf '%s\\n' "$@" > "$PWD/args.txt"
        echo "$PWD|$WP_KEY|$PODFLOW_CLI|$PODFLOW_CONFIG_FILE" > "$PWD/env.txt"
        echo '{"type":"assistant","message":{"content":[{"type":"text","text":"läuft"}]}}'
        echo '{"type":"result","is_error":false,"result":"ok"}'
        """
        try script.write(to: fake, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: fake.path)

        let runner = ClaudeRunner(setup: ClaudeSetup(binaryOverride: fake.path), pluginDirectory: plugin, cliPath: "/bundle/podflow")
        let log = OutputBox()
        let outcome = try await runner.run(
            mode: .publish, episodeFolder: folder,
            environment: ["WP_KEY": "geheim", "PODFLOW_CONFIG_FILE": "episode-371.yml"],
            onLog: { log.append($0) })

        XCTAssertEqual(outcome.exitCode, 0)
        XCTAssertFalse(outcome.isError)
        XCTAssertEqual(outcome.summary, "ok")
        XCTAssertEqual(log.value, "läuft")
        let args = try String(contentsOf: folder.appendingPathComponent("args.txt"), encoding: .utf8)
            .split(separator: "\n").map(String.init)
        XCTAssertEqual(args, ["-p", "/podflow:episode publish", "--plugin-dir", plugin.path,
                              "--output-format", "stream-json", "--verbose", "--dangerously-skip-permissions"])
        let env = try String(contentsOf: folder.appendingPathComponent("env.txt"), encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertTrue(env.hasSuffix("/371|geheim|/bundle/podflow|episode-371.yml"), env)
        XCTAssertTrue(FileManager.default.fileExists(atPath: folder.appendingPathComponent("run.log").path))
    }

    func testRunnerReportsMissingPieces() async {
        let runner = ClaudeRunner(setup: ClaudeSetup(binaryOverride: "/nonexistent/claude"), pluginDirectory: nil, cliPath: nil)
        do {
            _ = try await runner.run(mode: .prepare, episodeFolder: FileManager.default.temporaryDirectory, environment: [:], onLog: { _ in })
            XCTFail("expected error")
        } catch {
            XCTAssertTrue(error is ClaudeRunner.RunnerError)
        }
    }
}

/// The pipeline through its interface, with a fake `claude` that plays the
/// plugin: it records how it was called and writes step statuses.
final class EpisodePipelineTests: XCTestCase {
    private var root: URL!
    private var store: EpisodeStore!
    private var settings: EpisodePipeline.Settings!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("podflow-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root.appendingPathComponent("plugin"), withIntermediateDirectories: true)
        store = EpisodeStore(root: root.appendingPathComponent("Podflow"))
        settings = EpisodePipeline.Settings(
            environment: ["WP_KEY": "geheim"], missing: [],
            wordpressServer: "https://example.test", ftpHost: "ftp.example.test", ftpPort: "21",
            posterBaseURL: "http://files.example.test/data/")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    /// `body` is bash; `$1`/`$2` are `-p` and the prompt.
    private func pipeline(fakeClaude body: String) throws -> EpisodePipeline {
        let fake = root.appendingPathComponent("claude")
        try ("#!/bin/bash\n" + body + "\n").write(to: fake, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: fake.path)
        let runner = ClaudeRunner(
            setup: ClaudeSetup(binaryOverride: fake.path),
            pluginDirectory: root.appendingPathComponent("plugin"), cliPath: "/bundle/podflow")
        return EpisodePipeline(store: store, runner: runner, publishConfig: PublishConfig(configDirectory: root.appendingPathComponent("config")))
    }

    private func newEpisode() throws -> Episode {
        let video = root.appendingPathComponent("v.mp4")
        try "x".write(to: video, atomically: true, encoding: .utf8)
        let folder = try store.create(number: "371", title: "Test", type: .compilation, video: video, transcript: nil)
        return Episode(id: "371", folderURL: folder, state: store.readState(in: folder))
    }

    private func setStep(_ step: String, _ status: String, error: String = "") -> String {
        let filter = error.isEmpty
            ? ".steps[\"\(step)\"] = {status: \"\(status)\"}"
            : ".steps[\"\(step)\"] = {status: \"\(status)\", error: \"\(error)\"}"
        return "jq '\(filter)' state.json > s.tmp && mv s.tmp state.json"
    }

    private let ok = #"echo '{"type":"result","is_error":false,"result":"ok"}'"#

    func testPrepareReturnsStateReadyForReview() async throws {
        let pipeline = try pipeline(fakeClaude: [
            "echo \"$2\" > prompt.txt",
            setStep(StepID.factcheck, "done"),
            setStep(StepID.review, "in_progress"),
            #"echo '{"type":"assistant","message":{"content":[{"type":"text","text":"fertig"}]}}'"#,
            ok,
        ].joined(separator: "\n"))
        let episode = try newEpisode()
        let log = OutputBox()

        let state = try await pipeline.prepare(episode, settings: settings, onLog: { log.append($0) })

        XCTAssertEqual(state.phase, .review)
        XCTAssertEqual(log.value, "fertig")
        let prompt = try String(contentsOf: episode.folderURL!.appendingPathComponent("prompt.txt"), encoding: .utf8)
        XCTAssertEqual(prompt.trimmingCharacters(in: .whitespacesAndNewlines), "/podflow:episode prepare")
    }

    func testFailedStepIsReportedWithItsLabelAndReason() async throws {
        let pipeline = try pipeline(fakeClaude: [setStep(StepID.auphonicWait, "failed", error: "Auphonic: Error"), ok].joined(separator: "\n"))
        do {
            _ = try await pipeline.prepare(try newEpisode(), settings: settings, onLog: { _ in })
            XCTFail("expected error")
        } catch let error as EpisodePipeline.PipelineError {
            XCTAssertEqual(error, .stepFailed(label: "Auphonic verarbeitet", detail: "Auphonic: Error"))
            XCTAssertEqual(error.errorDescription, "„Auphonic verarbeitet“ ist fehlgeschlagen: Auphonic: Error")
        }
    }

    func testRunErrorWithoutFailedStepIsReported() async throws {
        let pipeline = try pipeline(fakeClaude: #"echo '{"type":"result","is_error":true,"result":"Nicht angemeldet"}'; exit 1"#)
        do {
            _ = try await pipeline.prepare(try newEpisode(), settings: settings, onLog: { _ in })
            XCTFail("expected error")
        } catch let error as EpisodePipeline.PipelineError {
            XCTAssertEqual(error, .runFailed("Nicht angemeldet"))
        }
    }

    func testMissingSettingsStopBeforeAnythingRuns() async throws {
        let pipeline = try pipeline(fakeClaude: "touch ran.txt")
        let episode = try newEpisode()
        settings.missing = ["Auphonic-Zugang"]
        do {
            _ = try await pipeline.prepare(episode, settings: settings, onLog: { _ in })
            XCTFail("expected error")
        } catch let error as EpisodePipeline.PipelineError {
            XCTAssertEqual(error, .missingSettings(["Auphonic-Zugang"]))
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: episode.folderURL!.appendingPathComponent("ran.txt").path))
    }

    func testEpisodeFromOtherMacCannotRun() async throws {
        let pipeline = try pipeline(fakeClaude: ok)
        do {
            _ = try await pipeline.prepare(Episode(id: "400"), settings: settings, onLog: { _ in })
            XCTFail("expected error")
        } catch let error as EpisodePipeline.PipelineError {
            XCTAssertEqual(error, .notOnThisMac)
        }
    }

    func testPublishPreparesCLIFilesAndPointsTheRunAtThem() async throws {
        let pipeline = try pipeline(fakeClaude: [
            "echo \"$2|$PODFLOW_CONFIG_FILE|$WP_KEY\" > call.txt",
            setStep(StepID.review, "done"),
            setStep(StepID.scheduled, "done"),
            ok,
        ].joined(separator: "\n"))
        let episode = try newEpisode()
        let folder = episode.folderURL!
        var components = DateComponents()
        (components.year, components.month, components.day, components.hour) = (2026, 11, 27, 9)
        let review = EpisodePipeline.Review(
            releaseDate: Calendar.current.date(from: components)!, coverFile: "cover.png", featuredFile: "wordpress.jpg")

        let state = try await pipeline.publish(episode, review: review, settings: settings, onLog: { _ in })

        XCTAssertEqual(state.phase, .scheduled)
        let call = try String(contentsOf: folder.appendingPathComponent("call.txt"), encoding: .utf8)
        XCTAssertEqual(call.trimmingCharacters(in: .whitespacesAndNewlines), "/podflow:episode publish|episode-371.yml|geheim")
        let config = try String(contentsOf: root.appendingPathComponent("config/episode-371.yml"), encoding: .utf8)
        XCTAssertTrue(config.contains("wordpress.jpg"))
        XCTAssertTrue(config.contains("371_test"))
        XCTAssertFalse(config.contains("geheim"))
        let cliState = try String(contentsOf: folder.appendingPathComponent("371.state.yml"), encoding: .utf8)
        XCTAssertTrue(cliState.contains("2026-11-27 09:00:00"))
    }
}

final class ReviewTests: XCTestCase {
    func testSuggestedReleaseDateIsNextFridayAtConfiguredTime() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Vienna")!
        // Monday 2026-11-23
        let now = calendar.date(from: DateComponents(year: 2026, month: 11, day: 23, hour: 12))!
        let date = ReviewView.suggestedReleaseDate(time: "09:00", now: now, calendar: calendar)
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute, .weekday], from: date)
        XCTAssertEqual([parts.year, parts.month, parts.day, parts.hour, parts.minute, parts.weekday], [2026, 11, 27, 9, 0, 6])
    }
}

@MainActor
final class SettingsTests: XCTestCase {
    func testSecretsGoToKeychainAndRunEnvironment() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "podflow-tests-\(UUID().uuidString)"))
        let keychain = MemoryKeychain()
        let settings = SettingsStore(defaults: defaults, keychain: keychain)
        XCTAssertEqual(settings.missingForRun.count, 4)

        settings.setSecret(.auphonicUser, "user")
        settings.setSecret(.auphonicPassword, "pw")
        settings.setSecret(.wordpressKey, "wp")
        settings.setSecret(.ftpUser, "ftp")
        settings.setSecret(.ftpPassword, "ftppw")
        settings.auphonicPreset = "PRESET"

        XCTAssertTrue(settings.missingForRun.isEmpty)
        XCTAssertEqual(try keychain.read(account: "WP_KEY"), "wp")
        XCTAssertNil(defaults.string(forKey: "WP_KEY"))
        let environment = settings.runEnvironment()
        XCTAssertEqual(environment["AUPHONIC_USER"], "user")
        XCTAssertEqual(environment["AUPHONIC_PRESET"], "PRESET")
        XCTAssertEqual(environment["FTP_PWD"], "ftppw")
        XCTAssertNil(environment["PODFLOW_WORKSPACE_KEY"])

        let reloaded = SettingsStore(defaults: defaults, keychain: keychain)
        XCTAssertEqual(reloaded.secret(.wordpressKey), "wp")
        XCTAssertEqual(reloaded.auphonicPreset, "PRESET")
    }
}

/// Runs the real CLI (`make cli` → build/podflow) against the files the app
/// generates. Skipped when the binary has not been built.
final class CLIContractTests: XCTestCase {
    func testGeneratedConfigAndStateAreAcceptedByPodflowCheck() async throws {
        let cli = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("build/podflow").path
        try XCTSkipUnless(FileManager.default.isExecutableFile(atPath: cli), "build/podflow missing — run `make cli`")

        let home = FileManager.default.temporaryDirectory.appendingPathComponent("podflow-tests-\(UUID().uuidString)")
        let folder = home.appendingPathComponent("Podflow/371")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: home) }
        for name in ["shownotes.md", "seo.md", "cover.png", "wordpress.png"] {
            try "x".write(to: folder.appendingPathComponent(name), atomically: true, encoding: .utf8)
        }

        let inputs = PublishConfig.Inputs(
            number: "371", title: "Test", audioBasename: "371_test", releaseDate: Date(),
            coverFile: "cover.png", featuredFile: "wordpress.png",
            wordpressServer: "https://example.test", ftpHost: "ftp.example.test", ftpPort: "21",
            posterBaseURL: "http://files.example.test/data/")
        let configFile = try PublishConfig(configDirectory: home.appendingPathComponent(".config/podflow"))
            .write(inputs, episodeFolder: folder)

        let result = try await ProcessRunner.run(
            cli, ["check"],
            environment: ProcessRunner.environment(adding: ["HOME": home.path, "PODFLOW_CONFIG_FILE": configFile]),
            currentDirectory: folder)

        XCTAssertEqual(result.exitCode, 0, result.output)
        for name in ["Shownotes", "SEO", "Cover", "WordPress-Bild", "Kapitel"] {
            XCTAssertTrue(result.output.contains("\(name) is already created"), result.output)
        }
    }
}
