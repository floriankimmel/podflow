import XCTest
@testable import Podflow

/// Pins the names the app shares with the shipped plugin: a rename on either
/// side fails here instead of in a paid Claude run.
final class PluginContractTests: XCTestCase {
    private static let skillDir = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("plugin/skills/episode")

    private func read(_ path: String) throws -> String {
        try String(contentsOf: Self.skillDir.appendingPathComponent(path), encoding: .utf8)
    }

    private func matches(_ pattern: String, in text: String) -> [String] {
        let regex = try! NSRegularExpression(pattern: pattern)
        return regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap {
            Range($0.range(at: 1), in: text).map { String(text[$0]) }
        }
    }

    func testSkillHasOneHeadingPerStageInStageOrder() throws {
        let headings = try read("SKILL.md").components(separatedBy: "\n").filter { $0.hasPrefix("### ") }
        let ids = headings.flatMap { matches("`([a-z_]+)`", in: $0) }
        XCTAssertEqual(ids, PipelineStage.all.map(\.id))
    }

    func testEverySEOLabelIsInThePromptOutputFormat() throws {
        let prompt = try read("prompts/03-seo.md")
        for label in SEOLabel.all {
            XCTAssertTrue(prompt.contains("**\(label):**"), "03-seo.md lacks **\(label):**")
        }
    }

    func testSkillReadsExactlyTheKnownSEOLabels() throws {
        let read = Set(matches(#"seo\.sh "([^"<]+)""#, in: try read("SKILL.md")))
        XCTAssertEqual(read, Set(SEOLabel.skill))
    }

    func testSkillNamesThePluginFiles() throws {
        let skill = try read("SKILL.md")
        for file in EpisodeFile.plugin {
            XCTAssertTrue(skill.contains("`\(file)`"), "SKILL.md does not name \(file)")
        }
        XCTAssertTrue(skill.contains("`\(EpisodeFile.coverBase).`"), "SKILL.md does not look for the cover by its base name")
    }

    func testRunEnvironmentMatchesWhatThePluginReads() throws {
        let scripts = try ["SKILL.md", "scripts/state.sh", "scripts/auphonic.sh", "scripts/seo.sh"].map(read).joined(separator: "\n")
        let read = Set(matches(#"\$\{?([A-Z][A-Z0-9_]+)"#, in: scripts))
        // Optional overrides and the scripts' own variables.
        let scriptOwned: Set = ["AUPHONIC_API_KEY", "AUPHONIC_BASE", "AUPHONIC_POLL_SECONDS", "PODFLOW_STATE_FILE",
                             "STATE_FILE", "AUTH", "BASE", "POLL", "CLAUDE_SKILL_DIR", "ARGUMENTS"]

        let cliSecrets: Set<SettingsStore.Secret> = [.ftpUser, .ftpPassword, .wordpressKey]
        let pluginProvided = Set(SettingsStore.Secret.allCases.filter { !cliSecrets.contains($0) }.map(\.rawValue))
            .union([EnvName.auphonicPreset, EnvName.backendURL, EnvName.cli])

        XCTAssertEqual(read.subtracting(scriptOwned), pluginProvided, "plugin reads ≠ app provides")

        let config = try PublishConfig.configYAML(PublishConfigTests.inputs)
        for secret in cliSecrets {
            XCTAssertTrue(config.contains("{{env.\(secret.rawValue)}}"), "CLI config lacks \(secret.rawValue)")
        }
    }

    func testStateScriptReportsTheAppsBackendProfile() throws {
        XCTAssertTrue(try read("scripts/state.sh").contains("profile: \"\(BackendProfile.video)\""))
    }
}
