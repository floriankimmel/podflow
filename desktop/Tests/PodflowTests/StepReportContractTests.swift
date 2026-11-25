import XCTest
@testable import Podflow

/// Step status is written by the plugin (`state.sh`), the CLI and the backend
/// and read by the app. `Tests/fixtures/step-report.json` is the one contract;
/// the plugin, CLI and backend tests check it too.
final class StepReportContractTests: XCTestCase {
    private struct Contract: Decodable {
        struct Report: Decodable {
            var step: String
            var status: String
        }
        var statuses: [String]
        var report: Report
    }

    private func contract() throws -> Contract {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("fixtures/step-report.json")
        return try JSONDecoder().decode(Contract.self, from: Data(contentsOf: url))
    }

    func testStepStatesMatchContract() throws {
        XCTAssertEqual(StepState.allCases.map(\.rawValue), try contract().statuses)
    }

    func testReportedStepDecodes() throws {
        let report = try contract().report
        let json = #"{"step":"\#(report.step)","status":"\#(report.status)","updatedAt":""}"#
        let status = try JSONDecoder().decode(StepStatus.self, from: Data(json.utf8))
        XCTAssertEqual(status.status.rawValue, report.status)
    }
}
