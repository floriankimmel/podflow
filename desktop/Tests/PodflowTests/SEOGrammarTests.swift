import XCTest
@testable import Podflow

/// `seo.md` is read by the app (`ContentParser`), the plugin (`seo.sh`) and
/// the CLI (`wordpress.SEOSections`, tested in Go). All must read the shared
/// fixtures in `Tests/fixtures/seo` the same way, as `expected.json` says.
final class SEOGrammarTests: XCTestCase {
    private static let desktop = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    private static let fixtures = desktop.appendingPathComponent("Tests/fixtures/seo")
    private static let script = desktop.appendingPathComponent("plugin/skills/episode/scripts/seo.sh").path

    private var scratch: URL!

    override func setUpWithError() throws {
        scratch = FileManager.default.temporaryDirectory.appendingPathComponent("podflow-seo-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: scratch)
    }

    private func expectations() throws -> [String: [String: String]] {
        let data = try Data(contentsOf: Self.fixtures.appendingPathComponent("expected.json"))
        return try JSONDecoder().decode([String: [String: String]].self, from: data)
    }

    private func scriptReads(_ label: String, in file: URL) async throws -> String {
        let result = try await ProcessRunner.run("/bin/bash", [Self.script, label, file.path], currentDirectory: scratch)
        XCTAssertEqual(result.exitCode, 0, result.output)
        return result.output.hasSuffix("\n") ? String(result.output.dropLast()) : result.output
    }

    /// Every fixture, plus `full.md` with CRLF line endings.
    private func cases() throws -> [(name: String, file: URL, expected: [String: String])] {
        let all = try expectations()
        var cases = try all.keys.sorted().map { name in
            (name: name, file: Self.fixtures.appendingPathComponent(name), expected: try XCTUnwrap(all[name]))
        }
        let crlf = scratch.appendingPathComponent("crlf.md")
        let full = try String(contentsOf: Self.fixtures.appendingPathComponent("full.md"), encoding: .utf8)
        try full.replacingOccurrences(of: "\n", with: "\r\n").write(to: crlf, atomically: true, encoding: .utf8)
        cases.append((name: "full.md as CRLF", file: crlf, expected: try XCTUnwrap(all["full.md"])))
        return cases
    }

    func testAppReadsFixturesAsExpected() throws {
        for fixture in try cases() {
            let markdown = try String(contentsOf: fixture.file, encoding: .utf8)
            let sections = ContentParser.seoSections(from: markdown)
            let read = Dictionary(uniqueKeysWithValues: sections.map { ($0.label, $0.text) })
            XCTAssertEqual(read, fixture.expected, fixture.name)
        }
    }

    func testPluginReadsFixturesAsExpected() async throws {
        for fixture in try cases() {
            for label in SEOLabel.all {
                let read = try await scriptReads(label, in: fixture.file)
                XCTAssertEqual(read, fixture.expected[label] ?? "", "\(fixture.name): \(label)")
            }
        }
    }
}
