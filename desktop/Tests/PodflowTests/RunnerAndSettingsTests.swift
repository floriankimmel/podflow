import XCTest
@testable import Podflow

@MainActor
final class SettingsStoreTests: XCTestCase {
    func testWorkspaceKeyPersistsInKeychainStoreAcrossRelaunch() throws {
        let keychain = MemoryKeychain()
        let suiteName = "settings-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = SettingsStore(defaults: defaults, keychain: keychain)
        settings.workspaceKey = "geheim"
        settings.backendURL = "https://backend.test"
        settings.storageRootPath = "/tmp/episodes"

        // Relaunch: a fresh store over the same persistence.
        let relaunched = SettingsStore(defaults: defaults, keychain: keychain)
        XCTAssertEqual(relaunched.workspaceKey, "geheim")
        XCTAssertEqual(relaunched.backendURL, "https://backend.test")
        XCTAssertEqual(relaunched.storageRootPath, "/tmp/episodes")
        XCTAssertTrue(relaunched.isBackendConfigured)

        // The key never lands in UserDefaults.
        XCTAssertNil(defaults.string(forKey: "workspaceKey"))
        XCTAssertEqual(try keychain.read(account: SettingsStore.Keys.workspaceKeyAccount), "geheim")
    }

    func testUnsetStorageRootShowsNeedsConfiguration() {
        let suiteName = "settings-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let settings = SettingsStore(defaults: defaults, keychain: MemoryKeychain())
        XCTAssertNil(settings.storageRootURL)
        XCTAssertFalse(settings.isBackendConfigured)
    }
}

final class PodflowRunnerTests: XCTestCase {
    private var binDir: URL!
    private var savedPath: String!

    override func setUp() async throws {
        binDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("runner-bin-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: binDir, withIntermediateDirectories: true)
        // Fake podflow that prints its working directory and arguments.
        let script = "#!/bin/sh\npwd\necho \"ARGS:$@\"\necho \"CONFIG:$PODFLOW_CONFIG_FILE\"\n"
        let scriptURL = binDir.appendingPathComponent("podflow")
        try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)
        savedPath = ProcessInfo.processInfo.environment["PATH"] ?? ""
        setenv("PATH", "\(binDir.path):\(savedPath!)", 1)
    }

    override func tearDown() async throws {
        setenv("PATH", savedPath, 1)
        try? FileManager.default.removeItem(at: binDir)
    }

    func testRunsWithEpisodeFolderAsWorkingDirectoryAndPresetConfig() async throws {
        let episode = FileManager.default.temporaryDirectory
            .appendingPathComponent("runner-episode-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: episode, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: episode) }

        let config = try PresetStore.parseConfiguration("""
        currentEpisode: "9"
        steps:
          - s3:
              buckets:
                - name: b
        """)
        let runner = PodflowRunner(binaryOverride: binDir.appendingPathComponent("podflow").path)
        let result = try await runner.run(
            command: ["publish"],
            episodeFolder: episode,
            configuration: config,
            backendURL: nil,
            workspaceKey: nil
        )
        XCTAssertEqual(result.exitCode, 0)
        let resolvedEpisode = episode.resolvingSymlinksInPath().path
        XCTAssertTrue(
            result.output.contains(resolvedEpisode) || result.output.contains(episode.path),
            "cwd must be the episode folder; got: \(result.output)")
        XCTAssertTrue(result.output.contains("ARGS:publish"))
        // Preset applied via PODFLOW_CONFIG_FILE (file name under ~/.config/podflow).
        XCTAssertTrue(result.output.contains("CONFIG:preset-run-"), "got: \(result.output)")

        // Per-run config file is cleaned up; global config.yml untouched.
        let configDir = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".config/podflow")
        let leftovers = (try? FileManager.default.contentsOfDirectory(atPath: configDir.path))?
            .filter { $0.hasPrefix("preset-run-") } ?? []
        XCTAssertTrue(leftovers.isEmpty, "per-run preset configs must be removed")
    }

    func testIsolatedConfigsForDifferentPresets() async throws {
        let episode = FileManager.default.temporaryDirectory
            .appendingPathComponent("runner-episode-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: episode, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: episode) }

        let runner = PodflowRunner(binaryOverride: binDir.appendingPathComponent("podflow").path)
        let configA = try PresetStore.parseConfiguration("currentEpisode: \"1\"")
        let configB = try PresetStore.parseConfiguration("currentEpisode: \"2\"")
        let a = try await runner.run(command: ["check"], episodeFolder: episode,
                                     configuration: configA, backendURL: nil, workspaceKey: nil)
        let b = try await runner.run(command: ["check"], episodeFolder: episode,
                                     configuration: configB, backendURL: nil, workspaceKey: nil)
        func configName(_ output: String) -> String? {
            output.components(separatedBy: "\n").first { $0.hasPrefix("CONFIG:") }
        }
        XCTAssertNotNil(configName(a.output))
        XCTAssertNotEqual(configName(a.output), configName(b.output), "each run gets its own config file")
    }
}

final class TranscriptionServiceTests: XCTestCase {
    func testPrimaryAudioPrefersFinalExport() throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("audio-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        let service = TranscriptionService(commandTemplate: "quicksubs {{audio}}")
        XCTAssertNil(service.primaryAudio(in: folder), "errors clearly when no audio exists")

        try Data().write(to: folder.appendingPathComponent("raw.wav"))
        XCTAssertEqual(service.primaryAudio(in: folder)?.lastPathComponent, "raw.wav")
        try Data().write(to: folder.appendingPathComponent("final.m4a"))
        XCTAssertEqual(service.primaryAudio(in: folder)?.lastPathComponent, "final.m4a",
                       "m4a export wins over raw wav")
    }

    func testTranscriptStatefulSkip() async throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("tr-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        // Existing transcript → skip without touching any engine.
        try "VORHANDEN".write(
            to: TranscriptionService.transcriptURL(episodeFolder: folder), atomically: true, encoding: .utf8)
        let service = TranscriptionService(
            commandTemplate: "definitely-not-installed {{audio}} {{output}}")
        let text = try await service.transcribe(episodeFolder: folder)
        XCTAssertEqual(text, "VORHANDEN")
    }

    func testMissingEngineReportsOnboarding() async throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("tr2-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        try Data().write(to: folder.appendingPathComponent("a.m4a"))

        let service = TranscriptionService(
            commandTemplate: "definitely-not-installed {{audio}} {{output}}")
        let missing = await service.checkEngine()
        XCTAssertTrue(missing.contains { $0.contains("definitely-not-installed") })

        do {
            _ = try await service.transcribe(episodeFolder: folder)
            XCTFail("must throw when the engine is missing")
        } catch let error as TranscriptionService.TranscriptionError {
            guard case .engineMissing = error else { return XCTFail("wrong error \(error)") }
        }
    }
}
