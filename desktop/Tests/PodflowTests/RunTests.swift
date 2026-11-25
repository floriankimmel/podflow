import XCTest
@testable import Podflow

/// `publish.json` is the seam to the CLI's `publish-episode`; the Go tests
/// read the same fixture.
final class PublishInputTests: XCTestCase {
    static let fixture = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("fixtures/publish.json")

    static var input: PublishInput {
        PublishInput(
            episodeNumber: "371", title: "Großglockner",
            releaseDate: Date(timeIntervalSince1970: 1_795_766_400), // 2026-11-27T08:00:00Z
            audioSlug: "371_grossglockner", coverFile: "cover.png", featuredImageFile: "wordpress.jpg",
            coverBaseURL: "http://files.example.test/data/", wordpressServer: "https://example.test",
            ftp: .init(host: "ftp.example.test", port: "2121"))
    }

    private func object(_ data: Data) throws -> NSDictionary {
        try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? NSDictionary)
    }

    func testEncodesAsTheSharedFixture() throws {
        XCTAssertEqual(try object(Self.input.json()), try object(Data(contentsOf: Self.fixture)))
    }

    func testWritesPublishJSONIntoTheEpisodeFolder() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("podflow-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        try Self.input.write(to: folder)

        let written = try Data(contentsOf: folder.appendingPathComponent(EpisodeFile.publishInput))
        XCTAssertEqual(try object(written), try object(Data(contentsOf: Self.fixture)))
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

    func testOutputSplitInsideACharacterIsKept() async throws {
        let result = try await ProcessRunner.run("/bin/bash", ["-c", #"printf 'l\xc3'; sleep 0.3; printf '\xa4uft\nende'"#])
        XCTAssertEqual(result.output, "läuft\nende")
    }

    func testProcessesThatExitAtOnceAlwaysReturn() async throws {
        for _ in 0..<50 {
            let result = try await ProcessRunner.run("/usr/bin/true", [])
            XCTAssertEqual(result.exitCode, 0)
        }
    }

    func testCancellingStopsTheProcess() async throws {
        let started = Date()
        let task = Task { try await ProcessRunner.run("/bin/sleep", ["30"]) }
        try await Task.sleep(for: .milliseconds(300))
        task.cancel()
        _ = try? await task.value
        XCTAssertLessThan(Date().timeIntervalSince(started), 5)
    }

    func testRunLogAndVisibleLogNeverContainSecrets() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("podflow-tests-\(UUID().uuidString)")
        let folder = root.appendingPathComponent("371")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let fake = root.appendingPathComponent("claude")
        try """
        #!/bin/bash
        echo "{\\"type\\":\\"assistant\\",\\"message\\":{\\"content\\":[{\\"type\\":\\"text\\",\\"text\\":\\"key=$WP_KEY\\"}]}}"
        echo '{"type":"result","is_error":false,"result":"ok"}'
        """.write(to: fake, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: fake.path)
        let runner = ClaudeRunner(setup: ClaudeSetup(binaryOverride: fake.path), pluginDirectory: root, cliPath: "/bundle/podflow")
        let log = OutputBox()

        _ = try await runner.run(mode: .prepare, episodeFolder: folder,
                                 environment: ["WP_KEY": "geheim/1234"], onLog: { log.append($0) })

        let runLog = try String(contentsOf: folder.appendingPathComponent(EpisodeFile.runLog), encoding: .utf8)
        XCTAssertFalse(runLog.contains("1234"), runLog)
        XCTAssertTrue(runLog.contains("key=***"), runLog)
        XCTAssertEqual(log.value, "key=***")
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
            coverBaseURL: "http://files.example.test/data/")
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
        return EpisodePipeline(store: store, runner: runner)
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

    func testCleanRunThatStopsBeforeTheGoalIsAFailure() async throws {
        let pipeline = try pipeline(fakeClaude: [
            setStep(StepID.auphonicCreate, "done"),
            #"echo '{"type":"result","is_error":false,"result":"Mode fehlt, Abbruch."}'"#,
        ].joined(separator: "\n"))
        do {
            _ = try await pipeline.prepare(try newEpisode(), settings: settings, onLog: { _ in })
            XCTFail("expected error")
        } catch let error as EpisodePipeline.PipelineError {
            XCTAssertEqual(error, .runFailed("Der Lauf hat „Prüfen“ nicht erreicht. Mode fehlt, Abbruch."))
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

    func testPublishWritesTheCLIInputBeforeTheRun() async throws {
        let pipeline = try pipeline(fakeClaude: [
            "echo \"$2|$WP_KEY\" > call.txt",
            "cp publish.json seen-by-run.json",
            setStep(StepID.review, "done"),
            setStep(StepID.scheduled, "done"),
            ok,
        ].joined(separator: "\n"))
        let episode = try newEpisode()
        let folder = episode.folderURL!
        let releaseDate = Date(timeIntervalSince1970: 1_795_766_400)
        let review = EpisodePipeline.Review(releaseDate: releaseDate, coverFile: "cover.png", featuredFile: "wordpress.jpg")

        let state = try await pipeline.publish(episode, review: review, settings: settings, onLog: { _ in })

        XCTAssertEqual(state.phase, .scheduled)
        let call = try String(contentsOf: folder.appendingPathComponent("call.txt"), encoding: .utf8)
        XCTAssertEqual(call.trimmingCharacters(in: .whitespacesAndNewlines), "/podflow:episode publish|geheim")
        let seen = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: Data(contentsOf: folder.appendingPathComponent("seen-by-run.json"))) as? [String: Any])
        XCTAssertEqual(seen["episodeNumber"] as? String, "371")
        XCTAssertEqual(seen["audioSlug"] as? String, "371_test")
        XCTAssertEqual(seen["featuredImageFile"] as? String, "wordpress.jpg")
        XCTAssertEqual(seen["releaseDate"] as? String, "2026-11-27T08:00:00Z")
        XCTAssertEqual((seen["ftp"] as? [String: String])?["port"], "21")
        let written = try String(contentsOf: folder.appendingPathComponent(EpisodeFile.publishInput), encoding: .utf8)
        XCTAssertFalse(written.contains("geheim"))
    }
}

final class ReviewTests: XCTestCase {
    func testSuggestedReleaseDateIsNextFridayAtConfiguredTime() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Vienna")!
        // Monday 2026-11-23
        let now = calendar.date(from: DateComponents(year: 2026, month: 11, day: 23, hour: 12))!
        let date = ReviewSession.suggestedReleaseDate(time: "09:00", now: now, calendar: calendar)
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
