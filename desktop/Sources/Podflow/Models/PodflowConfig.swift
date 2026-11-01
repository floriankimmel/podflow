import Foundation

// Mirror of the podflow CLI `Configuration` schema
// (internal/configuration/config.go). Presets serialize this verbatim so a
// materialized preset is a valid config.yml — no translation layer (D1).
//
// `{{env.*}}` and `{{...}}` placeholder tokens are plain strings here and are
// preserved exactly; secrets resolve only at CLI runtime.

struct PodflowConfig: Codable, Hashable, Sendable {
    var currentEpisode: String?
    var releaseDay: String?
    var releaseTime: String?
    var files: [EpisodeFile]?
    var steps: [Step]?
    var archive: Archive?
    var backend: Backend?

    struct EpisodeFile: Codable, Hashable, Sendable {
        var name: String?
        var fileName: String?
        var required: Bool?
        var notEmpty: Bool?
        var umlauteNotAllowed: Bool?
    }

    struct Archive: Codable, Hashable, Sendable {
        var target: String?
    }

    struct Backend: Codable, Hashable, Sendable {
        var url: String?
        var workspaceKey: String?
    }

    struct Step: Codable, Hashable, Sendable {
        var ftp: FTP?
        var download: FTP?
        var s3: S3?
        var auphonic: Auphonic?
        var wordpress: Wordpress?
        var steadyhq: SteadyHq?
    }

    struct FTP: Codable, Hashable, Sendable {
        var host: String?
        var port: String?
        var username: String?
        var password: String?
        var files: [FtpFile]?
        var delete: [FtpTargetFile]?
    }

    struct FtpFile: Codable, Hashable, Sendable {
        var source: String?
        var target: String?
    }

    struct FtpTargetFile: Codable, Hashable, Sendable {
        var target: String?
    }

    struct S3: Codable, Hashable, Sendable {
        var buckets: [S3Bucket]?
    }

    struct S3Bucket: Codable, Hashable, Sendable {
        var region: String?
        var name: String?
        var files: [FtpFile]?
    }

    struct Auphonic: Codable, Hashable, Sendable {
        var username: String?
        var password: String?
        var preset: String?
        var fileServer: String?
        var title: String?
        var files: [AuphonicFiles]?
    }

    struct AuphonicFiles: Codable, Hashable, Sendable {
        var image: String?
        var chapters: String?
        var episode: String?
    }

    struct Wordpress: Codable, Hashable, Sendable {
        var apiKey: String?
        var server: String?
        var image: String?
        var poster: String?
        var episode: String?
        var showNotes: String?
        var chapter: String?
        var contentFile: String?
    }

    struct SteadyHq: Codable, Hashable, Sendable {
        var apiKey: String?
        var image: String?
        var episode: String?
        var title: String?
        var showNotes: String?
    }
}

extension PodflowConfig {
    /// All `{{env.NAME}}` references used anywhere in this configuration.
    var referencedEnvVariables: Set<String> {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(self),
              let text = String(data: data, encoding: .utf8) else { return [] }
        var names: Set<String> = []
        let regex = #/\{\{env\.([A-Za-z0-9_]+)\}\}/#
        for match in text.matches(of: regex) {
            names.insert(String(match.1))
        }
        return names
    }

    /// The configured shownotes path (from wordpress step), used by generation
    /// to write podflow-readable output.
    var shownotesPath: String? {
        steps?.compactMap { $0.wordpress?.showNotes }.first
    }

    /// The configured SEO content file path (parsed by podflow for
    /// `**Meta-Description:**` / `**Focus Keywords:**`).
    var contentFilePath: String? {
        steps?.compactMap { $0.wordpress?.contentFile }.first
    }

    /// Publish stage keys this config actually contains; the pipeline view
    /// shows only these publish stages.
    var configuredPublishSteps: Set<String> {
        var keys: Set<String> = []
        for step in steps ?? [] {
            if step.ftp?.files?.isEmpty == false { keys.insert("ftp_upload") }
            if step.download != nil { keys.insert("download") }
            if step.s3 != nil { keys.insert("s3") }
            if step.wordpress != nil { keys.insert("wordpress") }
            if step.steadyhq != nil { keys.insert("steady") }
            if step.auphonic != nil { keys.insert("auphonic") }
        }
        return keys
    }

    /// A copy with the publish steps a profile excludes removed (D11/8.3).
    func removingPublishSteps(_ excluded: Set<String>) -> PodflowConfig {
        guard !excluded.isEmpty, let steps else { return self }
        var result = self
        result.steps = steps.map { step in
            var step = step
            if excluded.contains("ftp_delete") { step.ftp?.delete = nil }
            if excluded.contains("ftp_upload") { step.ftp?.files = nil }
            if excluded.contains("download") { step.download = nil }
            if excluded.contains("s3") { step.s3 = nil }
            if excluded.contains("wordpress") { step.wordpress = nil }
            if excluded.contains("steady") { step.steadyhq = nil }
            if excluded.contains("auphonic") { step.auphonic = nil }
            if let ftp = step.ftp, ftp.files == nil, ftp.delete == nil {
                step.ftp = nil
            }
            return step
        }
        return result
    }
}
