import Foundation

/// Episode folders on disk: one folder per episode number under the root
/// (`~/Podflow/<number>/`), holding `state.json` and the generated files.
struct EpisodeStore {
    enum StoreError: LocalizedError, Equatable {
        case missingNumber
        case missingTitle
        case missingVideo
        case missingTranscript
        case exists(String)

        var errorDescription: String? {
            switch self {
            case .missingNumber: return "Bitte eine Episodennummer angeben."
            case .missingTitle: return "Bitte einen Titel angeben."
            case .missingVideo: return "Bitte das fertig geschnittene Video auswählen."
            case .missingTranscript: return "Für eine Zencastr-Aufnahme wird die Transkript-Datei benötigt."
            case .exists(let number): return "Episode \(number) gibt es bereits."
            }
        }
    }

    let root: URL
    let fileManager: FileManager

    static var defaultRoot: URL {
        URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Podflow", isDirectory: true)
    }

    init(root: URL = EpisodeStore.defaultRoot, fileManager: FileManager = .default) {
        self.root = root
        self.fileManager = fileManager
    }

    func folder(for number: String) -> URL {
        root.appendingPathComponent(number, isDirectory: true)
    }

    // MARK: Create / list

    @discardableResult
    func create(number: String, title: String, type: EpisodeType, video: URL?, transcript: URL?) throws -> URL {
        let number = number.trimmingCharacters(in: .whitespaces)
        let title = title.trimmingCharacters(in: .whitespaces)
        guard !number.isEmpty else { throw StoreError.missingNumber }
        guard !title.isEmpty else { throw StoreError.missingTitle }
        guard let video else { throw StoreError.missingVideo }
        if type == .zencastr, transcript == nil { throw StoreError.missingTranscript }

        let folder = folder(for: number)
        guard !fileManager.fileExists(atPath: folder.path) else { throw StoreError.exists(number) }
        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)

        if let transcript {
            try fileManager.copyItem(at: transcript, to: folder.appendingPathComponent(EpisodeFile.transcript))
        }
        let state = EpisodeState(
            number: number,
            title: title,
            type: type,
            audioBasename: Self.audioBasename(number: number, title: title),
            video: video.path
        )
        try writeState(state, in: folder)
        return folder
    }

    /// Moves the episode folder to the Trash, so a mistake can be undone in Finder.
    func delete(number: String) throws {
        let folder = folder(for: number)
        guard fileManager.fileExists(atPath: folder.path) else { return }
        try fileManager.trashItem(at: folder, resultingItemURL: nil)
    }

    func listEpisodes() -> [Episode] {
        guard let entries = try? fileManager.contentsOfDirectory(
            at: root, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]
        ) else { return [] }
        return entries.compactMap { folder in
            guard let state = readState(in: folder) else { return nil }
            return Episode(id: state.number, folderURL: folder, state: state)
        }
    }

    // MARK: State

    func readState(in folder: URL) -> EpisodeState? {
        guard let data = try? Data(contentsOf: folder.appendingPathComponent(EpisodeFile.state)) else { return nil }
        return try? JSONDecoder().decode(EpisodeState.self, from: data)
    }

    func writeState(_ state: EpisodeState, in folder: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(state).write(to: folder.appendingPathComponent(EpisodeFile.state), options: .atomic)
    }

    // MARK: Review draft

    enum ImageSlot: Sendable {
        /// Podcast cover; uploaded to the server and used as Podlove poster.
        case cover
        /// WordPress featured image.
        case featured

        var base: String {
            switch self {
            case .cover: return EpisodeFile.coverBase
            case .featured: return EpisodeFile.featuredBase
            }
        }
    }

    /// Reads the generated files of an episode into one editable value.
    func loadReviewDraft(in folder: URL) -> ReviewDraft {
        ReviewDraft(
            shownotes: readText(EpisodeFile.shownotes, in: folder),
            posts: ContentParser.socialPosts(from: readText(EpisodeFile.social, in: folder)),
            seo: ContentParser.seoSections(from: readText(EpisodeFile.seo, in: folder)),
            factcheck: readText(EpisodeFile.factcheck, in: folder),
            coverFile: imageName(base: EpisodeFile.coverBase, in: folder),
            featuredFile: imageName(base: EpisodeFile.featuredBase, in: folder),
            releaseDate: readReviewFile(in: folder).releaseDate
        )
    }

    /// Writes the editable parts (shownotes, social posts, release date) back.
    /// SEO and the fact-check are read-only. An empty post list never
    /// overwrites `social.md`.
    func saveReviewDraft(_ draft: ReviewDraft, in folder: URL) throws {
        try writeText(draft.shownotes, to: EpisodeFile.shownotes, in: folder)
        if !draft.posts.isEmpty {
            try writeText(ContentParser.socialMarkdown(from: draft.posts), to: EpisodeFile.social, in: folder)
        }
        if draft.releaseDate != readReviewFile(in: folder).releaseDate {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(ReviewFile(releaseDate: draft.releaseDate))
                .write(to: folder.appendingPathComponent(EpisodeFile.review), options: .atomic)
        }
    }

    /// `review.json`: review decisions that have no other home.
    private struct ReviewFile: Codable {
        var releaseDate: Date?
    }

    private func readReviewFile(in folder: URL) -> ReviewFile {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let data = try? Data(contentsOf: folder.appendingPathComponent(EpisodeFile.review)),
              let file = try? decoder.decode(ReviewFile.self, from: data) else { return ReviewFile() }
        return file
    }

    /// Copies a picked image into the episode folder and returns its file name.
    @discardableResult
    func storeImage(_ source: URL, as slot: ImageSlot, in folder: URL) throws -> String {
        try storeImage(source, base: slot.base, in: folder)
    }

    private func readText(_ name: String, in folder: URL) -> String {
        (try? String(contentsOf: folder.appendingPathComponent(name), encoding: .utf8)) ?? ""
    }

    private func writeText(_ text: String, to name: String, in folder: URL) throws {
        try text.write(to: folder.appendingPathComponent(name), atomically: true, encoding: .utf8)
    }

    /// Replaces an earlier pick with a different extension.
    private func storeImage(_ source: URL, base: String, in folder: URL) throws -> String {
        if let existing = imageName(base: base, in: folder) {
            try fileManager.removeItem(at: folder.appendingPathComponent(existing))
        }
        let ext = source.pathExtension.isEmpty ? "png" : source.pathExtension.lowercased()
        let name = "\(base).\(ext)"
        try fileManager.copyItem(at: source, to: folder.appendingPathComponent(name))
        return name
    }

    private func imageName(base: String, in folder: URL) -> String? {
        let files = (try? fileManager.contentsOfDirectory(atPath: folder.path)) ?? []
        return files.sorted().first { ($0 as NSString).deletingPathExtension == base }
    }

    // MARK: Naming

    /// `<number>_<title-slug>`: ASCII only, so it is safe as a file name on the
    /// podcast server and as Podlove slug (the CLI rejects umlauts).
    static func audioBasename(number: String, title: String) -> String {
        "\(number)_\(slug(title))"
    }

    static func slug(_ text: String) -> String {
        let replacements = ["ä": "ae", "ö": "oe", "ü": "ue", "ß": "ss"]
        var lowered = text.lowercased()
        for (umlaut, ascii) in replacements {
            lowered = lowered.replacingOccurrences(of: umlaut, with: ascii)
        }
        let folded = lowered.folding(options: .diacriticInsensitive, locale: Locale(identifier: "de"))
        var result = ""
        var lastWasDash = true
        for scalar in folded.unicodeScalars {
            let isAlnum = scalar.isASCII && (CharacterSet.alphanumerics.contains(scalar))
            if isAlnum {
                result.unicodeScalars.append(scalar)
                lastWasDash = false
            } else if !lastWasDash {
                result.append("-")
                lastWasDash = true
            }
        }
        while result.hasSuffix("-") { result.removeLast() }
        return result.isEmpty ? "episode" : String(result.prefix(60))
    }

    /// Next free episode number: highest known number + 1.
    static func nextNumber(known: [String]) -> String {
        let highest = known.compactMap { Int($0) }.max()
        return highest.map { String($0 + 1) } ?? ""
    }
}

// MARK: - Generated content parsing

enum ContentParser {
    /// Splits `social.md` into its "## Platform" blocks, keeping order.
    static func socialPosts(from markdown: String) -> [SocialPost] {
        var posts: [SocialPost] = []
        var current: (platform: String, lines: [String])?
        for line in stripFence(markdown).components(separatedBy: "\n") {
            if line.hasPrefix("## ") {
                if let current { posts.append(post(current)) }
                current = (String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces), [])
            } else {
                current?.lines.append(line)
            }
        }
        if let current { posts.append(post(current)) }
        return posts
    }

    static func socialMarkdown(from posts: [SocialPost]) -> String {
        posts.map { "## \($0.platform)\n\($0.text.trimmingCharacters(in: .whitespacesAndNewlines))" }
            .joined(separator: "\n\n") + "\n"
    }

    /// Splits `seo.md` into its "**Label:**" sections, keeping order.
    static func seoSections(from markdown: String) -> [SEOSection] {
        var sections: [SEOSection] = []
        var current: (label: String, lines: [String])?
        for line in stripFence(markdown).components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("**"), trimmed.hasSuffix(":**"), trimmed.count > 5 {
                if let current { sections.append(section(current)) }
                current = (String(trimmed.dropFirst(2).dropLast(3)), [])
            } else {
                current?.lines.append(line)
            }
        }
        if let current { sections.append(section(current)) }
        return sections
    }

    private static func post(_ raw: (platform: String, lines: [String])) -> SocialPost {
        SocialPost(platform: raw.platform, text: joined(raw.lines))
    }

    private static func section(_ raw: (label: String, lines: [String])) -> SEOSection {
        SEOSection(label: raw.label, text: joined(raw.lines))
    }

    private static func joined(_ lines: [String]) -> String {
        lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Models sometimes wrap the whole output in a ``` fence; drop those lines.
    /// CR line endings are dropped too.
    private static func stripFence(_ markdown: String) -> String {
        markdown.replacingOccurrences(of: "\r", with: "").components(separatedBy: "\n")
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("```") }
            .joined(separator: "\n")
    }
}
