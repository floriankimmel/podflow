import XCTest
@testable import Podflow

final class RPPGeneratorTests: XCTestCase {
    private let template = """
    <REAPER_PROJECT 0.1 "6.77/macOS-arm64" 1714026050
      RECORD_PATH "Recordings" ""
      <TRACK {AAA}
        NAME Peter
        TRACKID {AAA}
        <FXCHAIN
          WNDRECT 0 0 0 0
        >
      >
      <TRACK {BBB}
        NAME Florian
        TRACKID {BBB}
      >
      <TRACK {CCC}
        NAME Geordi
        TRACKID {CCC}
      >
    >
    """

    private let itemTemplate = """
    <ITEM
      POSITION 0
      LENGTH {length}
      IGUID {{iguid}}
      NAME {filename}
      SOFFS 0
      GUID {{guid}}
      <SOURCE WAVE
        FILE "Recordings/{filename}"
      >
    >
    """

    private func generator() -> RPPGenerator {
        RPPGenerator(templateText: template, itemTemplateText: itemTemplate)
    }

    func testItemsLandOnMappedTracks() throws {
        let project = try generator().generateProject(items: [
            .init(fileName: "a-laufendentdecken.wav", track: "Peter", length: 123.456),
            .init(fileName: "b-florian.wav", track: "Florian", length: 99.5),
            .init(fileName: "c-guest.flac", track: "Geordi", length: 42),
        ])

        // Each file lands inside its speaker's track block.
        let peterBlock = project.range(of: "NAME Peter")!.lowerBound..<project.range(of: "NAME Florian")!.lowerBound
        XCTAssertTrue(project[peterBlock].contains("Recordings/a-laufendentdecken.wav"))
        let florianBlock = project.range(of: "NAME Florian")!.lowerBound..<project.range(of: "NAME Geordi")!.lowerBound
        XCTAssertTrue(project[florianBlock].contains("Recordings/b-florian.wav"))
        XCTAssertTrue(project[project.range(of: "NAME Geordi")!.lowerBound...].contains("Recordings/c-guest.flac"))

        // Item fields per design D10.
        XCTAssertTrue(project.contains("POSITION 0"))
        XCTAssertTrue(project.contains("SOFFS 0"))
        XCTAssertTrue(project.contains("LENGTH 123.456000000"))
        // FLAC source type for flac files.
        XCTAssertTrue(project.contains("<SOURCE FLAC"))
        XCTAssertTrue(project.contains("<SOURCE WAVE"))
        // No unresolved placeholders, fresh GUIDs.
        XCTAssertFalse(project.contains("{{guid}}"))
        XCTAssertFalse(project.contains("{{iguid}}"))
        XCTAssertFalse(project.contains("{length}"))
        XCTAssertFalse(project.contains("{filename}"))
    }

    func testFreshGUIDsPerItem() throws {
        let project = try generator().generateProject(items: [
            .init(fileName: "a.wav", track: "Peter", length: 1),
            .init(fileName: "b.wav", track: "Peter", length: 2),
        ])
        let guids = project.components(separatedBy: "\n")
            .filter { $0.trimmingCharacters(in: .whitespaces).hasPrefix("GUID {") }
        XCTAssertEqual(guids.count, 2)
        XCTAssertEqual(Set(guids).count, 2, "every item needs its own GUID")
    }

    func testUnknownTrackFails() {
        XCTAssertThrowsError(try generator().generateProject(items: [
            .init(fileName: "x.wav", track: "Unbekannt", length: 1),
        ]))
    }

    func testBundledTemplatesLoad() throws {
        let generator = try RPPGenerator.bundled()
        XCTAssertTrue(generator.templateText.contains("NAME Peter"))
        XCTAssertTrue(generator.templateText.contains("RECORD_PATH \"Recordings\""))
        XCTAssertTrue(generator.itemTemplateText.contains("{{iguid}}"))
    }
}
