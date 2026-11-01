import XCTest
@testable import Podflow

final class DiscoveryTests: XCTestCase {
    private var tempDir: URL!

    override func setUp() async throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("disc-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testListsSubfoldersAsEpisodesSortedByNumber() throws {
        for slug in ["259_alt", "260_neu", "ohne-nummer"] {
            try FileManager.default.createDirectory(
                at: tempDir.appendingPathComponent(slug), withIntermediateDirectories: true)
        }
        try Data().write(to: tempDir.appendingPathComponent("loose-file.txt"))

        let episodes = EpisodeDiscovery().listEpisodes(root: tempDir)
        XCTAssertEqual(episodes.map(\.slug), ["260_neu", "259_alt", "ohne-nummer"])
        XCTAssertEqual(episodes[0].episodeNumber, "260")
        XCTAssertNil(episodes[2].episodeNumber)
    }

    func testEmptyRootYieldsNoEpisodes() {
        XCTAssertTrue(EpisodeDiscovery().listEpisodes(root: tempDir).isEmpty)
        XCTAssertTrue(EpisodeDiscovery()
            .listEpisodes(root: tempDir.appendingPathComponent("missing")).isEmpty)
    }

    func testReadsStateYmlMetadata() throws {
        let folder = tempDir.appendingPathComponent("259_marathon", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try """
        metadata:
          episodeNumber: "259"
          releaseDate: "2026-11-05"
          title: Marathon Spezial
        ftpUploaded: true
        s3Uploaded: true
        wordpressBlogCreated: true
        steadyHqCreated: true
        auphonicProduction: true
        downloaded: true
        """.write(to: folder.appendingPathComponent("259_marathon.state.yml"), atomically: true, encoding: .utf8)

        let episode = EpisodeDiscovery().episode(at: folder)
        XCTAssertEqual(episode.episodeNumber, "259")
        XCTAssertEqual(episode.title, "Marathon Spezial")
        XCTAssertEqual(episode.releaseDate, "2026-11-05")
        XCTAssertEqual(episode.identity, "259")
        XCTAssertEqual(episode.doneSteps, [
            "ftp_upload", "s3", "wordpress", "steady", "auphonic", "download",
        ])
    }

    func testDetectsExistingStateYmlWithDifferentName() throws {
        let folder = tempDir.appendingPathComponent("261_umbenannt", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try """
        metadata:
          episodeNumber: "261"
          title: Alte Folge
        """.write(to: folder.appendingPathComponent("state.yml"), atomically: true, encoding: .utf8)

        let episode = EpisodeDiscovery().episode(at: folder)
        XCTAssertEqual(episode.episodeNumber, "261")
        XCTAssertEqual(episode.title, "Alte Folge")
    }

    func testPrefersSlugStateYmlOverPlainStateYml() throws {
        let folder = tempDir.appendingPathComponent("262_beide", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try "metadata:\n  title: Falsch\n".write(
            to: folder.appendingPathComponent("state.yml"), atomically: true, encoding: .utf8)
        try "metadata:\n  title: Richtig\n".write(
            to: folder.appendingPathComponent("262_beide.state.yml"), atomically: true, encoding: .utf8)

        XCTAssertEqual(EpisodeDiscovery().episode(at: folder).title, "Richtig")
    }

    func testDerivesDoneStepsFromFiles() throws {
        let folder = tempDir.appendingPathComponent("263_dateien", isDirectory: true)
        let recordings = folder.appendingPathComponent("Recordings", isDirectory: true)
        try FileManager.default.createDirectory(at: recordings, withIntermediateDirectories: true)
        try Data().write(to: recordings.appendingPathComponent("track1.m4a"))
        try Data().write(to: folder.appendingPathComponent("263_dateien.m4a"))
        try Data().write(to: folder.appendingPathComponent("263_dateien.md"))
        try Data().write(to: folder.appendingPathComponent("content-263_dateien.md"))

        let episode = EpisodeDiscovery().episode(at: folder)
        XCTAssertTrue(episode.doneSteps.isSuperset(of: ["ingest", "reaper", "shownotes", "seo"]))
        XCTAssertFalse(episode.doneSteps.contains("transcribe"), "no transcript file")
        XCTAssertFalse(episode.doneSteps.contains("social"), "no social file")

        try Data().write(to: folder.appendingPathComponent("263_dateien.transcript.txt"))
        try Data().write(to: folder.appendingPathComponent("263_dateien.social.md"))
        let again = EpisodeDiscovery().episode(at: folder)
        XCTAssertTrue(again.doneSteps.isSuperset(of: ["transcribe", "social"]))
    }

    func testAppMetadataRoundTripProfileAndPreset() throws {
        let folder = tempDir.appendingPathComponent("300_video", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let discovery = EpisodeDiscovery()
        try discovery.writeAppMetadata(
            EpisodeDiscovery.AppMetadata(profile: "video", presetID: "ABC"), to: folder)
        let episode = discovery.episode(at: folder)
        XCTAssertEqual(episode.profileID, "video")
        XCTAssertEqual(episode.presetID, "ABC")
    }

    func testFinishedAudioDetection() throws {
        let folder = tempDir.appendingPathComponent("259", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let discovery = EpisodeDiscovery()
        XCTAssertFalse(discovery.hasFinishedAudio(in: folder), "awaiting edited audio")
        try Data().write(to: folder.appendingPathComponent("259.mp3"))
        XCTAssertFalse(discovery.hasFinishedAudio(in: folder), "mp3 alone is not enough")
        try Data().write(to: folder.appendingPathComponent("259.m4a"))
        XCTAssertTrue(discovery.hasFinishedAudio(in: folder))
    }
}

final class ProfileTests: XCTestCase {
    func testStudioProfileStages() {
        let keys = EpisodeProfile.studio.stages.map(\.key)
        XCTAssertEqual(keys, [
            "ingest", "reaper",
            "transcribe", "shownotes", "social", "seo",
            "ftp_upload", "download", "s3", "wordpress", "steady", "auphonic",
        ])
        XCTAssertTrue(EpisodeProfile.studio.excludedPublishSteps.isEmpty)
    }

    func testVideoProfileExcludesAuphonicPublish() {
        let keys = EpisodeProfile.video.stages.map(\.key)
        XCTAssertEqual(keys, [
            "video", "auphonic_production", "download_audio",
            "transcribe", "shownotes", "social", "seo",
            "ftp_upload", "download", "s3", "wordpress", "steady",
        ])
        XCTAssertFalse(keys.contains("auphonic"), "Auphonic ran up front; publish stage set omits it")
        XCTAssertEqual(EpisodeProfile.video.excludedPublishSteps, ["auphonic"])
    }

    func testStagesFilteredByPresetConfig() {
        var config = PodflowConfig()
        config.steps = [PodflowConfig.Step(
            ftp: PodflowConfig.FTP(files: [PodflowConfig.FtpFile(source: "a", target: "b")]),
            wordpress: PodflowConfig.Wordpress()
        )]
        XCTAssertEqual(config.configuredPublishSteps, ["ftp_upload", "wordpress"])

        let keys = EpisodeProfile.studio
            .stages(configuredPublish: config.configuredPublishSteps).map(\.key)
        XCTAssertEqual(keys, [
            "ingest", "reaper", "transcribe", "shownotes", "social", "seo",
            "ftp_upload", "wordpress",
        ])
        XCTAssertEqual(
            EpisodeProfile.studio.stages(configuredPublish: nil).map(\.key),
            EpisodeProfile.studio.stages.map(\.key),
            "nil config shows everything")
    }

    func testProfileLookupDefaultsToStudio() {
        XCTAssertEqual(EpisodeProfile.named("video").id, "video")
        XCTAssertEqual(EpisodeProfile.named(nil).id, "studio")
        XCTAssertEqual(EpisodeProfile.named("unbekannt").id, "studio")
    }
}

final class ReadinessTests: XCTestCase {
    func testNamesMissingFiles() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ready-\(UUID().uuidString)/259_test", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir.deletingLastPathComponent()) }

        let check = ReadinessCheck()
        var missing = check.missingItems(episodeFolder: tempDir, episodeNumber: "259", config: nil)
        XCTAssertEqual(missing.count, 6, "everything missing initially")

        for file in ["259_x.mp3", "259_test.m4a", "259_test.chapters.txt", "259_test.md", "content-259_test.md"] {
            try Data("x".utf8).write(to: tempDir.appendingPathComponent(file))
        }
        missing = check.missingItems(episodeFolder: tempDir, episodeNumber: "259", config: nil)
        XCTAssertEqual(missing.map(\.name), ["Cover (PNG)"], "names the one missing file")

        try Data("x".utf8).write(to: tempDir.appendingPathComponent("259_test.png"))
        XCTAssertTrue(check.missingItems(episodeFolder: tempDir, episodeNumber: "259", config: nil).isEmpty)
    }
}

final class BackendClientTests: XCTestCase {
    final class MockURLProtocol: URLProtocol {
        nonisolated(unsafe) static var handler: ((URLRequest) -> (Int, Data))?
        override class func canInit(with request: URLRequest) -> Bool { true }
        override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
        override func startLoading() {
            guard let handler = Self.handler else { return }
            let (status, data) = handler(request)
            let response = HTTPURLResponse(
                url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        }
        override func stopLoading() {}
    }

    private func makeSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }

    func testListSendsWorkspaceKeyAndDecodes() async throws {
        MockURLProtocol.handler = { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-Workspace-Key"), "secret")
            XCTAssertEqual(request.url?.path, "/episodes")
            let json = """
            [{"id":"259","episodeNumber":"259","title":"Test","steps":
              [{"step":"ftp_upload","status":"in_progress","updatedAt":"2026-11-01T10:00:00Z"}],
              "updatedAt":"2026-11-01T10:00:00Z"}]
            """
            return (200, Data(json.utf8))
        }
        let client = BackendClient(baseURL: "https://backend.test", workspaceKey: "secret", session: makeSession())
        let episodes = try await client.listEpisodes()
        XCTAssertEqual(episodes.count, 1)
        XCTAssertEqual(episodes[0].status(of: "ftp_upload"), .inProgress)
        XCTAssertTrue(episodes[0].anyStepInProgress)
        XCTAssertEqual(episodes[0].status(of: "s3"), .pending, "unknown steps default to pending")
    }

    func testRejectedCredentialThrowsUnauthorized() async {
        MockURLProtocol.handler = { _ in (401, Data("{\"error\":\"invalid workspace key\"}".utf8)) }
        let client = BackendClient(baseURL: "https://backend.test", workspaceKey: "wrong", session: makeSession())
        do {
            _ = try await client.listEpisodes()
            XCTFail("must throw")
        } catch let error as BackendError {
            XCTAssertEqual(error, .unauthorized)
        } catch {
            XCTFail("wrong error \(error)")
        }
    }

    func testUnconfiguredThrows() async {
        let client = BackendClient(baseURL: "", workspaceKey: "", session: makeSession())
        do {
            _ = try await client.listEpisodes()
            XCTFail("must throw")
        } catch let error as BackendError {
            XCTAssertEqual(error, .notConfigured)
        } catch {
            XCTFail("wrong error \(error)")
        }
    }
}

final class AudioDownloadTests: XCTestCase {
    func testResolveURLTemplate() {
        let url = ServerAudioDownloader.resolveURL(
            template: "https://server/podcast/{{episodeNumber}}_{{slug}}.mp3",
            episodeNumber: "259", slug: "259_marathon")
        XCTAssertEqual(url?.absoluteString, "https://server/podcast/259_259_marathon.mp3")
    }

    func testAwaitingWhenServerHasNoFile() async throws {
        BackendClientTests.MockURLProtocol.handler = { _ in (404, Data()) }
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [BackendClientTests.MockURLProtocol.self]
        let downloader = ServerAudioDownloader(session: URLSession(configuration: config))

        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("dl-\(UUID().uuidString)/259", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder.deletingLastPathComponent()) }

        let state = try await downloader.attemptDownload(
            template: "https://server/{{episodeNumber}}.mp3", episodeFolder: folder, episodeNumber: "259")
        XCTAssertEqual(state, .awaitingProducedAudio)

        BackendClientTests.MockURLProtocol.handler = { _ in (200, Data("mp3-bytes".utf8)) }
        let done = try await downloader.attemptDownload(
            template: "https://server/{{episodeNumber}}.mp3", episodeFolder: folder, episodeNumber: "259")
        guard case .downloaded(let url) = done else { return XCTFail("expected download") }
        XCTAssertEqual(url.lastPathComponent, "259.mp3")
        XCTAssertEqual(try Data(contentsOf: url), Data("mp3-bytes".utf8))
    }
}
