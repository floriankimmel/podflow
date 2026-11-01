import XCTest
@testable import Podflow

final class AuphonicTests: XCTestCase {
    final class Recorder: URLProtocol {
        struct Call {
            var path: String
            var method: String
            var body: Data
        }
        nonisolated(unsafe) static var calls: [Call] = []
        nonisolated(unsafe) static var status = 200
        nonisolated(unsafe) static var response = Data("{\"data\":{\"uuid\":\"prod-1\"}}".utf8)

        override class func canInit(with request: URLRequest) -> Bool { true }
        override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
        override func startLoading() {
            let body = request.httpBody ?? request.httpBodyStream.map { stream in
                stream.open()
                defer { stream.close() }
                var data = Data()
                let bufferSize = 64 * 1024
                let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
                defer { buffer.deallocate() }
                while stream.hasBytesAvailable {
                    let read = stream.read(buffer, maxLength: bufferSize)
                    if read <= 0 { break }
                    data.append(buffer, count: read)
                }
                return data
            } ?? Data()
            Self.calls.append(Call(
                path: request.url!.path, method: request.httpMethod ?? "", body: body))
            let response = HTTPURLResponse(
                url: request.url!, statusCode: Self.status, httpVersion: nil, headerFields: nil)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Self.response)
            client?.urlProtocolDidFinishLoading(self)
        }
        override func stopLoading() {}
    }

    override func setUp() {
        Recorder.calls = []
        Recorder.status = 200
    }

    private func client() -> AuphonicClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [Recorder.self]
        return AuphonicClient(
            baseURL: "https://auphonic.test", username: "user", password: "pass",
            session: URLSession(configuration: config))
    }

    func testCreateUploadStartSequence() async throws {
        let auphonic = client()
        let production = try await auphonic.createProduction(
            preset: "preset-1", title: "LEP300", youtubeDescription: "Beschreibung vorab")
        XCTAssertEqual(production.uuid, "prod-1")

        let video = FileManager.default.temporaryDirectory.appendingPathComponent("v-\(UUID().uuidString).mp4")
        try Data("video".utf8).write(to: video)
        defer { try? FileManager.default.removeItem(at: video) }
        try await auphonic.uploadVideo(productionUUID: production.uuid, fileURL: video)
        try await auphonic.startProduction(productionUUID: production.uuid)

        XCTAssertEqual(Recorder.calls.map(\.path), [
            "/api/productions.json",
            "/api/production/prod-1/upload.json",
            "/api/production/prod-1/start.json",
        ])
        // Description-first ordering: metadata carried in the create call (D4).
        let createBody = String(data: Recorder.calls[0].body, encoding: .utf8) ?? ""
        XCTAssertTrue(createBody.contains("Beschreibung vorab"))
    }

    func testDescriptionAppliedLaterWhenGeneratedAfterwards() async throws {
        let auphonic = client()
        _ = try await auphonic.createProduction(preset: "p", title: "T", youtubeDescription: nil)
        let createBody = String(data: Recorder.calls[0].body, encoding: .utf8) ?? ""
        XCTAssertFalse(createBody.contains("summary"), "no description yet")

        try await auphonic.updateMetadata(productionUUID: "prod-1", youtubeDescription: "Nachträglich")
        XCTAssertEqual(Recorder.calls[1].path, "/api/production/prod-1.json")
        let updateBody = String(data: Recorder.calls[1].body, encoding: .utf8) ?? ""
        XCTAssertTrue(updateBody.contains("Nachträglich"))
    }

    func testMisconfigurationErrorsClearly() async {
        let auphonic = AuphonicClient(baseURL: "https://auphonic.test", username: "", password: "")
        do {
            _ = try await auphonic.createProduction(preset: "p", title: "T", youtubeDescription: nil)
            XCTFail("must throw")
        } catch let error as AuphonicClient.AuphonicError {
            guard case .misconfigured = error else { return XCTFail("wrong error \(error)") }
        } catch {
            XCTFail("wrong error \(error)")
        }

        Recorder.status = 401
        Recorder.response = Data("unauthorized".utf8)
        do {
            _ = try await client().createProduction(preset: "p", title: "T", youtubeDescription: nil)
            XCTFail("must throw")
        } catch let error as AuphonicClient.AuphonicError {
            guard case .http(401, _) = error else { return XCTFail("wrong error \(error)") }
        } catch {
            XCTFail("wrong error \(error)")
        }
    }
}
