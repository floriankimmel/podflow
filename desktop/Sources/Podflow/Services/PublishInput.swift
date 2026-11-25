import Foundation

/// What the bundled CLI needs to publish the website post:
/// `podflow publish-episode publish.json`, run in the episode folder.
/// The CLI owns its config and progress; secrets come from the environment.
/// `Tests/fixtures/publish.json` pins this shape for the app and the CLI.
struct PublishInput: Encodable, Equatable {
    struct FTP: Encodable, Equatable {
        var host: String
        var port: String
    }

    var episodeNumber: String
    var title: String
    var releaseDate: Date
    /// Base name of the audio file on the server (Podlove slug).
    var audioSlug: String
    /// File names inside the episode folder.
    var coverFile: String
    var featuredImageFile: String
    var coverBaseURL: String
    var wordpressServer: String
    var ftp: FTP

    func json() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(self)
    }

    func write(to episodeFolder: URL) throws {
        try json().write(to: episodeFolder.appendingPathComponent(EpisodeFile.publishInput), options: .atomic)
    }
}
