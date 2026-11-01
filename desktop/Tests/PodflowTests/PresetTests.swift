import XCTest
@testable import Podflow

@MainActor
final class PresetTests: XCTestCase {
    private var tempDir: URL!

    override func setUp() async throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("preset-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    private func store() -> PresetStore {
        PresetStore(directory: tempDir)
    }

    private let sampleYAML = """
    currentEpisode: "259"
    releaseDay: Tuesday
    releaseTime: "05:00"
    files:
      - name: Episode
        fileName: "{{folderName}}.m4a"
        required: true
    steps:
      - ftp:
          host: example.com
          username: "{{env.FTP_USER}}"
          password: "{{env.FTP_PWD}}"
          files:
            - source: "{{episodeNumber}}_{{folderName}}.mp3"
              target: "podcast/{{episodeNumber}}_{{folderName}}.mp3"
      - wordpress:
          apiKey: "{{env.WP_KEY}}"
          server: https://example.com
          showNotes: "{{folderName}}.md"
          contentFile: "content-{{folderName}}.md"
      - auphonic:
          username: "{{env.AUPHONIC_USER}}"
          password: "{{env.AUPHONIC_PWD}}"
          preset: abc
          title: "LEP{{episodeNumber}}"
          files:
            - episode: "{{folderName}}.m4a"
    """

    func testRoundTripPreservesEnvReferences() throws {
        let config = try PresetStore.parseConfiguration(sampleYAML)
        let serialized = try PresetStore.serializeConfiguration(config)
        XCTAssertTrue(serialized.contains("{{env.FTP_PWD}}"))
        XCTAssertTrue(serialized.contains("{{env.WP_KEY}}"))
        let reparsed = try PresetStore.parseConfiguration(serialized)
        XCTAssertEqual(config, reparsed)
    }

    func testCaptureFromConfigFile() throws {
        let configURL = tempDir.appendingPathComponent("config.yml")
        try sampleYAML.write(to: configURL, atomically: true, encoding: .utf8)
        let store = store()
        let preset = try store.captureFromConfigFile(at: configURL, name: "Studio Standard")
        XCTAssertEqual(preset.name, "Studio Standard")
        XCTAssertEqual(preset.configuration.currentEpisode, "259")
        XCTAssertTrue(preset.isDefault, "first captured preset becomes the default")
        XCTAssertEqual(preset.configuration.steps?.count, 3)
    }

    func testFirstPresetBecomesDefaultAndExactlyOneDefault() throws {
        let store = store()
        let config = try PresetStore.parseConfiguration(sampleYAML)
        store.add(Preset(name: "A", configuration: config))
        store.add(Preset(name: "B", configuration: config))
        XCTAssertEqual(store.presets.filter(\.isDefault).count, 1)
        XCTAssertEqual(store.defaultPreset?.name, "A")
        store.setDefault(store.presets[1])
        XCTAssertEqual(store.presets.filter(\.isDefault).count, 1)
        XCTAssertEqual(store.defaultPreset?.name, "B")
    }

    func testDeletePromotesDefaultAndBlocksLast() throws {
        let store = store()
        let config = try PresetStore.parseConfiguration(sampleYAML)
        store.add(Preset(name: "A", configuration: config))
        store.add(Preset(name: "B", configuration: config))
        try store.delete(store.presets.first { $0.name == "A" }!)
        XCTAssertEqual(store.defaultPreset?.name, "B")
        XCTAssertThrowsError(try store.delete(store.presets[0])) { error in
            guard case PresetError.lastPresetUndeletable = error else {
                return XCTFail("wrong error: \(error)")
            }
        }
    }

    func testPersistenceAcrossRelaunch() throws {
        let config = try PresetStore.parseConfiguration(sampleYAML)
        store().add(Preset(name: "Persist", configuration: config))
        let reloaded = store()
        XCTAssertEqual(reloaded.presets.count, 1)
        XCTAssertEqual(reloaded.presets[0].name, "Persist")
        XCTAssertEqual(reloaded.presets[0].configuration.currentEpisode, "259")
    }

    func testExportImportBundleRoundTripAndCollisions() throws {
        let config = try PresetStore.parseConfiguration(sampleYAML)
        let source = store()
        source.add(Preset(name: "Studio", configuration: config))
        source.add(Preset(name: "Video", configuration: config))
        let bundle = try source.exportBundle()

        // No resolved secrets in the bundle.
        let text = String(data: bundle, encoding: .utf8)!
        XCTAssertTrue(text.contains("{{env.FTP_PWD}}"))

        // Import into a fresh (empty) library: one step to full provisioning.
        let destDir = tempDir.appendingPathComponent("dest")
        try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)
        let destination = PresetStore(directory: destDir)
        try destination.importBundle(bundle)
        XCTAssertEqual(destination.presets.count, 2)
        XCTAssertEqual(destination.presets.filter(\.isDefault).count, 1)

        // Importing again onto a non-empty library keeps both colliding entries.
        try destination.importBundle(bundle)
        XCTAssertEqual(destination.presets.count, 4)
        XCTAssertEqual(Set(destination.presets.map(\.id)).count, 4, "ids must stay unique")
        XCTAssertEqual(Set(destination.presets.map(\.name)).count, 4, "names must stay distinct")
    }

    func testValidationRejectsEmptySteps() {
        let store = store()
        let preset = Preset(name: "Leer", configuration: PodflowConfig())
        XCTAssertThrowsError(try store.validate(preset))
    }

    func testMissingEnvVariables() throws {
        let store = store()
        let config = try PresetStore.parseConfiguration(sampleYAML)
        let preset = Preset(name: "X", configuration: config)
        let missing = store.missingEnvVariables(for: preset, environment: ["FTP_USER": "x"])
        XCTAssertEqual(missing, ["AUPHONIC_PWD", "AUPHONIC_USER", "FTP_PWD", "WP_KEY"])
        let none = store.missingEnvVariables(for: preset, environment: [
            "FTP_USER": "a", "FTP_PWD": "b", "WP_KEY": "c", "AUPHONIC_USER": "d", "AUPHONIC_PWD": "e",
        ])
        XCTAssertTrue(none.isEmpty)
    }

    func testRemovingPublishStepsForVideoProfile() throws {
        let config = try PresetStore.parseConfiguration(sampleYAML)
        let filtered = config.removingPublishSteps(EpisodeProfile.video.excludedPublishSteps)
        XCTAssertNil(filtered.steps?.compactMap(\.auphonic).first, "video profile must drop the Auphonic publish step")
        XCTAssertNotNil(filtered.steps?.compactMap(\.wordpress).first, "other steps stay")
        XCTAssertNotNil(filtered.steps?.compactMap(\.ftp).first)
    }
}
