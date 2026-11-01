import Foundation
import AVFoundation

/// Generates the Reaper project (`<slug>.RPP`) inside the episode folder from
/// the configured template: one item per source file on the mapped speaker
/// track — POSITION 0, probed LENGTH, SOFFS 0, fresh GUIDs, relative
/// `Recordings/<file>` source path (design D10).
struct RPPGenerator {
    enum GeneratorError: LocalizedError {
        case templateNotFound
        case trackNotFound(String)

        var errorDescription: String? {
            switch self {
            case .templateNotFound:
                return "Reaper-Template nicht gefunden."
            case .trackNotFound(let name):
                return "Track \(name) existiert nicht im Reaper-Template."
            }
        }
    }

    var templateText: String
    var itemTemplateText: String

    /// Bundled defaults mirror ~/Documents/workspace/dotfiles/reaper.
    static func bundled() throws -> RPPGenerator {
        guard let dir = Bundle.module.url(forResource: "reaper", withExtension: nil),
              let template = try? String(contentsOf: dir.appendingPathComponent("template.RPP"), encoding: .utf8),
              let item = try? String(contentsOf: dir.appendingPathComponent("item.xml"), encoding: .utf8) else {
            throw GeneratorError.templateNotFound
        }
        return RPPGenerator(templateText: template, itemTemplateText: item)
    }

    /// Loads overridden templates from a directory, falling back to bundled.
    static func load(overrideDirectory: URL?) throws -> RPPGenerator {
        if let dir = overrideDirectory {
            let templateURL = dir.appendingPathComponent("template.RPP")
            let itemURL = dir.appendingPathComponent("item.xml")
            if let template = try? String(contentsOf: templateURL, encoding: .utf8),
               let item = try? String(contentsOf: itemURL, encoding: .utf8) {
                return RPPGenerator(templateText: template, itemTemplateText: item)
            }
        }
        return try bundled()
    }

    struct SourceItem {
        var fileName: String       // file name inside Recordings/
        var track: String          // template track name
        var length: Double         // seconds
    }

    static func probeDuration(of url: URL) async -> Double {
        let asset = AVURLAsset(url: url)
        guard let duration = try? await asset.load(.duration) else { return 0 }
        let seconds = CMTimeGetSeconds(duration)
        return seconds.isFinite ? seconds : 0
    }

    private static func reaperGUID() -> String {
        "{\(UUID().uuidString)}"
    }

    private func renderItem(_ item: SourceItem) -> String {
        let sourceType = item.fileName.lowercased().hasSuffix(".flac") ? "FLAC" : "WAVE"
        var text = itemTemplateText
        text = text.replacingOccurrences(of: "{{iguid}}", with: Self.reaperGUID())
        text = text.replacingOccurrences(of: "{{guid}}", with: Self.reaperGUID())
        text = text.replacingOccurrences(of: "{length}", with: String(format: "%.9f", item.length))
        text = text.replacingOccurrences(of: "{filename}", with: item.fileName)
        text = text.replacingOccurrences(of: "<SOURCE WAVE", with: "<SOURCE \(sourceType)")
        return text
    }

    /// Generates the project text: items are inserted at the end of their
    /// speaker's `<TRACK` block. Unknown tracks raise `trackNotFound`.
    func generateProject(items: [SourceItem]) throws -> String {
        var lines = templateText.components(separatedBy: "\n")

        let grouped = Dictionary(grouping: items, by: \.track)
        for (track, trackItems) in grouped.sorted(by: { $0.key < $1.key }) {
            guard let range = try trackBlockRange(lines: lines, trackName: track) else {
                throw GeneratorError.trackNotFound(track)
            }
            // Insert rendered items just before the track's closing line.
            let indent = "    "
            var rendered: [String] = []
            for item in trackItems {
                let block = renderItem(item)
                rendered += block.components(separatedBy: "\n").map { indent + $0 }
            }
            lines.insert(contentsOf: rendered, at: range.closingLine)
        }
        return lines.joined(separator: "\n")
    }

    /// Finds a `<TRACK` block whose NAME matches; returns its closing line index.
    private func trackBlockRange(lines: [String], trackName: String) throws -> (openingLine: Int, closingLine: Int)? {
        var index = 0
        while index < lines.count {
            let trimmed = lines[index].trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("<TRACK") {
                let opening = index
                var depth = 1
                var name: String?
                var cursor = index + 1
                while cursor < lines.count, depth > 0 {
                    let inner = lines[cursor].trimmingCharacters(in: .whitespaces)
                    if inner.hasPrefix("<") { depth += 1 }
                    else if inner == ">" { depth -= 1 }
                    if depth == 1, name == nil, inner.hasPrefix("NAME ") {
                        name = String(inner.dropFirst("NAME ".count))
                            .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                    }
                    cursor += 1
                }
                let closing = cursor - 1
                if name == trackName {
                    return (opening, closing)
                }
                index = cursor
            } else {
                index += 1
            }
        }
        return nil
    }

    /// Full flow: probe durations, map speakers, write `<slug>.RPP`.
    func writeProject(
        episodeFolder: URL,
        slug: String,
        recordings: [URL],
        speakerMap: ZencastrIngest.SpeakerMap
    ) async throws -> URL {
        var items: [SourceItem] = []
        for url in recordings {
            let length = await Self.probeDuration(of: url)
            items.append(SourceItem(
                fileName: url.lastPathComponent,
                track: speakerMap.track(for: url.lastPathComponent),
                length: max(length, 0)
            ))
        }
        let project = try generateProject(items: items)
        let projectURL = episodeFolder.appendingPathComponent("\(slug).RPP")
        try project.write(to: projectURL, atomically: true, encoding: .utf8)
        return projectURL
    }
}
