import Foundation

/// Editable generation prompts (design D4). Bundled Markdown defaults are
/// copied to Application Support on first use; edits persist there and are
/// used on the next run.
struct PromptStore {
    enum Prompt: String, CaseIterable, Identifiable {
        case shownotes = "01-shownotes"
        case socialMedia = "02-social-media"
        case seo = "03-seo"

        var id: String { rawValue }
        var displayName: String {
            switch self {
            case .shownotes: return "Shownotes"
            case .socialMedia: return "Social Media"
            case .seo: return "SEO & Metadata"
            }
        }
    }

    let directory: URL
    let fileManager: FileManager

    init(directory: URL? = nil, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.directory = directory ?? FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Podflow/prompts", isDirectory: true)
    }

    private func bundledURL(for prompt: Prompt) -> URL? {
        Bundle.module.url(forResource: "prompts", withExtension: nil)?
            .appendingPathComponent("\(prompt.rawValue).md")
    }

    private func editedURL(for prompt: Prompt) -> URL {
        directory.appendingPathComponent("\(prompt.rawValue).md")
    }

    /// The effective prompt text: the edited copy when present, else bundled.
    func text(for prompt: Prompt) throws -> String {
        let edited = editedURL(for: prompt)
        if let text = try? String(contentsOf: edited, encoding: .utf8) {
            return text
        }
        guard let bundled = bundledURL(for: prompt),
              let text = try? String(contentsOf: bundled, encoding: .utf8) else {
            throw NSError(domain: "PromptStore", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Prompt \(prompt.rawValue) fehlt."])
        }
        return text
    }

    func save(_ text: String, for prompt: Prompt) throws {
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        try text.write(to: editedURL(for: prompt), atomically: true, encoding: .utf8)
    }

    func resetToBundled(_ prompt: Prompt) {
        try? fileManager.removeItem(at: editedURL(for: prompt))
    }

    func isEdited(_ prompt: Prompt) -> Bool {
        fileManager.fileExists(atPath: editedURL(for: prompt).path)
    }

    /// Replaces `{{placeholder}}` tokens in a prompt.
    static func substitute(_ template: String, values: [String: String]) -> String {
        var text = template
        for (key, value) in values {
            text = text.replacingOccurrences(of: "{{\(key)}}", with: value)
        }
        return text
    }
}
