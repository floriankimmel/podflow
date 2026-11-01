import Foundation

/// Pre-publish readiness (task 9.1): names each required file that is still
/// missing in the episode folder (mp3, m4a, chapters, cover art, shownotes,
/// SEO content file).
struct ReadinessCheck {
    struct Item: Identifiable {
        var id: String { name }
        var name: String
        var fileName: String
        var present: Bool
    }

    let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func check(episodeFolder: URL, episodeNumber: String?, config: PodflowConfig?) -> [Item] {
        let slug = episodeFolder.lastPathComponent
        let files = (try? fileManager.contentsOfDirectory(atPath: episodeFolder.path)) ?? []

        func exists(suffix: String) -> String? {
            files.first { $0.lowercased().hasSuffix(suffix) }
        }

        let shownotes = GenerationService.shownotesURL(
            episodeFolder: episodeFolder, config: config, episodeNumber: episodeNumber)
        let seo = GenerationService.seoURL(
            episodeFolder: episodeFolder, config: config, episodeNumber: episodeNumber)

        return [
            Item(name: "MP3", fileName: exists(suffix: ".mp3") ?? "\(episodeNumber ?? "n")_\(slug).mp3",
                 present: exists(suffix: ".mp3") != nil),
            Item(name: "M4A", fileName: exists(suffix: ".m4a") ?? "\(slug).m4a",
                 present: exists(suffix: ".m4a") != nil),
            Item(name: "Kapitelmarken", fileName: exists(suffix: ".chapters.txt") ?? "\(slug).chapters.txt",
                 present: exists(suffix: ".chapters.txt") != nil),
            Item(name: "Cover (PNG)", fileName: exists(suffix: ".png") ?? "\(slug).png",
                 present: exists(suffix: ".png") != nil),
            Item(name: "Shownotes", fileName: shownotes.lastPathComponent,
                 present: fileManager.fileExists(atPath: shownotes.path)),
            Item(name: "SEO-Content", fileName: seo.lastPathComponent,
                 present: fileManager.fileExists(atPath: seo.path)),
        ]
    }

    func missingItems(episodeFolder: URL, episodeNumber: String?, config: PodflowConfig?) -> [Item] {
        check(episodeFolder: episodeFolder, episodeNumber: episodeNumber, config: config)
            .filter { !$0.present }
    }
}
