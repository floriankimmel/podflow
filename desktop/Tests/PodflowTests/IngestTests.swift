import XCTest
@testable import Podflow

final class IngestTests: XCTestCase {
    private var tempDir: URL!

    override func setUp() async throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ingest-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    private func makeZencastrSource(number: String, recordings: [[String]]) throws -> URL {
        let source = tempDir.appendingPathComponent(number, isDirectory: true)
        for (index, files) in recordings.enumerated() {
            let folder = source.appendingPathComponent("recording-\(index + 1)", isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            for file in files {
                try Data("audio".utf8).write(to: folder.appendingPathComponent(file))
            }
        }
        return source
    }

    func testAggregatesAudioAcrossAllRecordingFolders() throws {
        let source = try makeZencastrSource(number: "259", recordings: [
            ["a-laufendentdecken.wav", "b-florian.wav", "notes.txt"],
            ["c-guest-der_3.flac", "clip.mov"],
        ])
        let ingest = ZencastrIngest()
        let audio = try ingest.collectAudioFiles(source: source)
        XCTAssertEqual(audio.map(\.lastPathComponent).sorted(),
                       ["a-laufendentdecken.wav", "b-florian.wav", "c-guest-der_3.flac"],
                       "all recording-* folders aggregate; mov/txt excluded")
    }

    func testCreateEpisodeCopiesIntoRecordingsAndDerivesNumber() throws {
        let source = try makeZencastrSource(number: "259", recordings: [
            ["a-laufendentdecken.wav"],
            ["a-laufendentdecken.wav", "b-florian.wav"],
        ])
        let root = tempDir.appendingPathComponent("root", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let ingest = ZencastrIngest()
        let result = try ingest.createEpisode(source: source, storageRoot: root, slug: "259_test")

        XCTAssertEqual(result.episodeNumber, "259")
        XCTAssertEqual(result.episodeFolder.lastPathComponent, "259_test")
        XCTAssertEqual(result.copiedFiles.count, 3)
        // Duplicate names across recording folders get suffixed, nothing lost.
        let names = result.copiedFiles.map(\.lastPathComponent).sorted()
        XCTAssertEqual(names, ["a-laufendentdecken-2.wav", "a-laufendentdecken.wav", "b-florian.wav"])
        XCTAssertTrue(names.allSatisfy { name in
            FileManager.default.fileExists(
                atPath: result.episodeFolder.appendingPathComponent("Recordings/\(name)").path)
        })

        // Episode is now discoverable under the root.
        let discovered = EpisodeDiscovery().listEpisodes(root: root)
        XCTAssertEqual(discovered.map(\.slug), ["259_test"])
        XCTAssertEqual(discovered[0].episodeNumber, "259")
    }

    func testCreateEpisodeRefusesExistingFolder() throws {
        let source = try makeZencastrSource(number: "7", recordings: [["a-florian.wav"]])
        let root = tempDir.appendingPathComponent("root2", isDirectory: true)
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent("7_test"), withIntermediateDirectories: true)
        XCTAssertThrowsError(
            try ZencastrIngest().createEpisode(source: source, storageRoot: root, slug: "7_test"))
    }

    func testSpeakerMap() {
        let map = ZencastrIngest.SpeakerMap.standard
        XCTAssertEqual(map.track(for: "xyz-laufendentdecken.wav"), "Peter")
        XCTAssertEqual(map.track(for: "abc-FLORIAN.wav"), "Florian")
        XCTAssertEqual(map.track(for: "guest-maria-der_3.wav"), "Geordi")
        XCTAssertEqual(map.track(for: "anything-else.flac"), "Geordi")
    }

    func testEpisodeNumberFromSourceFolder() {
        XCTAssertEqual(ZencastrIngest.episodeNumber(fromSource: URL(fileURLWithPath: "/x/259")), "259")
        XCTAssertEqual(ZencastrIngest.episodeNumber(fromSource: URL(fileURLWithPath: "/x/308_special")), "308")
        XCTAssertNil(ZencastrIngest.episodeNumber(fromSource: URL(fileURLWithPath: "/x/no-number")))
    }
}
