import XCTest
@testable import Podflow

/// In-memory backend: records calls, can be told to fail.
final class FakeBackend: BackendClientProtocol, @unchecked Sendable {
    var episodes: [BackendEpisode] = []
    var listError: Error?
    var deleteError: Error?
    private(set) var putMetadataCalls: [(number: String, metadata: BackendMetadata)] = []
    private(set) var deleted: [String] = []

    func listEpisodes() async throws -> [BackendEpisode] {
        if let listError { throw listError }
        return episodes
    }
    func getEpisode(number: String) async throws -> BackendEpisode { throw BackendError.notFound }
    func reportStep(number: String, step: String, status: StepState, metadata: BackendMetadata) async throws {}
    func putMetadata(number: String, metadata: BackendMetadata) async throws { putMetadataCalls.append((number, metadata)) }
    func putContent(number: String, key: String, body: String) async throws {}
    func deleteEpisode(number: String) async throws {
        if let deleteError { throw deleteError }
        deleted.append(number)
    }
}

@MainActor
final class EpisodeCatalogTests: XCTestCase {
    private var root: URL!
    private var store: EpisodeStore!
    private var configDir: URL!
    private var backend: FakeBackend!
    private var configured = true

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("podflow-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        store = EpisodeStore(root: root.appendingPathComponent("Podflow"))
        configDir = root.appendingPathComponent("config")
        backend = FakeBackend()
        configured = true
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    private var catalog: EpisodeCatalog {
        EpisodeCatalog(store: store, publishConfig: PublishConfig(configDirectory: configDir),
                       backend: { [unowned self] in configured ? backend : nil })
    }

    private func video() throws -> URL {
        let url = root.appendingPathComponent("v.mp4")
        try "x".write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func record(_ number: String?, id: String? = nil, title: String, steps: [String: StepState] = [:]) -> BackendEpisode {
        BackendEpisode(
            id: id ?? number ?? UUID().uuidString, episodeNumber: number, title: title,
            steps: steps.map { StepStatus(step: $0.key, status: $0.value, updatedAt: "") })
    }

    func testLocalStateWinsAndBackendAddsTheOtherHostsEpisodes() async throws {
        try store.create(number: "370", title: "Lokal", type: .compilation, video: try video(), transcript: nil)
        backend.episodes = [
            record("370", title: "Backend-Titel", steps: [StepID.auphonicCreate: .done]),
            record("371", title: "Vom Co-Host", steps: [StepID.factcheck: .done]),
        ]

        let listing = await catalog.list()

        XCTAssertEqual(listing.connection, .connected)
        XCTAssertEqual(listing.episodes.map(\.id), ["371", "370"])
        let local = listing.episodes[1]
        XCTAssertTrue(local.isLocal)
        XCTAssertEqual(local.title, "Lokal")
        XCTAssertEqual(local.backendSteps.map(\.step), [StepID.auphonicCreate])
        let remote = listing.episodes[0]
        XCTAssertFalse(remote.isLocal)
        XCTAssertEqual(remote.title, "Vom Co-Host")
    }

    func testRecordWithoutNumberIsKeyedByIdAndSortedAfterNumbers() async {
        backend.episodes = [record(nil, id: "spezial", title: "Ohne Nummer"), record("2", title: "Zwei"), record("10", title: "Zehn")]

        let listing = await catalog.list()

        XCTAssertEqual(listing.episodes.map(\.id), ["10", "2", "spezial"])
    }

    func testBackendProblemsKeepLocalEpisodes() async throws {
        try store.create(number: "5", title: "Lokal", type: .compilation, video: try video(), transcript: nil)

        backend.listError = BackendError.unauthorized
        var listing = await catalog.list()
        XCTAssertEqual(listing.connection, .authError)
        XCTAssertEqual(listing.episodes.map(\.id), ["5"])

        backend.listError = URLError(.notConnectedToInternet)
        listing = await catalog.list()
        XCTAssertEqual(listing.connection, .offline)
        XCTAssertEqual(listing.episodes.map(\.id), ["5"])

        configured = false
        listing = await catalog.list()
        XCTAssertEqual(listing.connection, .unconfigured)
        XCTAssertEqual(listing.episodes.map(\.id), ["5"])
    }

    func testCreateMakesFolderAndAnnouncesEpisode() async throws {
        try await catalog.create(number: "12", title: "Neu", type: .compilation, video: try video(), transcript: nil)

        XCTAssertNotNil(store.readState(in: store.folder(for: "12")))
        XCTAssertEqual(backend.putMetadataCalls.map(\.number), ["12"])
        XCTAssertEqual(backend.putMetadataCalls.first?.metadata.profile, BackendProfile.video)
        XCTAssertEqual(backend.putMetadataCalls.first?.metadata.title, "Neu")
    }

    func testDeleteRemovesSharedStatusFolderAndCLIConfig() async throws {
        try store.create(number: "8", title: "Weg", type: .compilation, video: try video(), transcript: nil)
        try FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
        let configFile = configDir.appendingPathComponent(PublishConfig.configFileName(number: "8"))
        try "x".write(to: configFile, atomically: true, encoding: .utf8)

        let listed = await catalog.list().episodes
        let episode = try XCTUnwrap(listed.first)
        try await catalog.delete(episode)

        XCTAssertEqual(backend.deleted, ["8"])
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.folder(for: "8").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: configFile.path))
    }

    func testBackendFailureLeavesLocalEpisodeUntouched() async throws {
        try store.create(number: "9", title: "Bleibt", type: .compilation, video: try video(), transcript: nil)
        backend.deleteError = BackendError.http(500)

        let listed = await catalog.list().episodes
        let episode = try XCTUnwrap(listed.first)
        do {
            try await catalog.delete(episode)
            XCTFail("expected the backend error")
        } catch {
            XCTAssertEqual(error as? BackendError, .http(500))
        }

        XCTAssertTrue(FileManager.default.fileExists(atPath: store.folder(for: "9").path))
    }

    func testOtherHostsEpisodeIsOnlyRemovedFromSharedStatus() async throws {
        backend.episodes = [record("40", title: "Fremd")]

        let listed = await catalog.list().episodes
        let episode = try XCTUnwrap(listed.first)
        try await catalog.delete(episode)

        XCTAssertEqual(backend.deleted, ["40"])
    }
}
