import SwiftUI

/// Editor for generated artifacts (transcript, shownotes, social, SEO).
/// Edits persist to the episode file and are pushed to the backend; they are
/// not overwritten unless the step is explicitly regenerated (task 4.3).
struct MarkdownEditorView: View {
    let episode: Episode
    let contentKey: String
    let episodeFolder: URL

    @EnvironmentObject var model: AppModel
    @EnvironmentObject var presets: PresetStore
    @Environment(\.dismiss) private var dismiss

    @State private var text = ""
    @State private var dirty = false
    @State private var error: String?

    private var fileURL: URL {
        let config = presets.defaultPreset?.configuration
        switch contentKey {
        case ContentKey.transcript:
            return TranscriptionService.transcriptURL(episodeFolder: episodeFolder)
        case ContentKey.shownotes:
            return GenerationService.shownotesURL(
                episodeFolder: episodeFolder, config: config, episodeNumber: episode.episodeNumber)
        case ContentKey.seo:
            return GenerationService.seoURL(
                episodeFolder: episodeFolder, config: config, episodeNumber: episode.episodeNumber)
        default:
            return GenerationService.socialURL(episodeFolder: episodeFolder)
        }
    }

    private var title: String {
        switch contentKey {
        case ContentKey.transcript: return "Transkript"
        case ContentKey.shownotes: return "Shownotes"
        case ContentKey.seo: return "SEO & Metadata"
        default: return "Social Posts"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.title2.weight(.bold))
                Spacer()
                Text(fileURL.lastPathComponent)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            TextEditor(text: $text)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(8)
                .glassPanel(cornerRadius: 12)
                .onChange(of: text) { dirty = true }

            if let error {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
            }

            HStack {
                Spacer()
                Button("Schließen") { dismiss() }
                    .buttonStyle(GlassButtonStyle())
                Button("Speichern") { save() }
                    .buttonStyle(GlassButtonStyle(prominent: true))
                    .disabled(!dirty)
            }
        }
        .padding(20)
        .frame(width: 720, height: 620)
        .background(Theme.backdrop)
        .onAppear { load() }
    }

    private func load() {
        text = (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
        dirty = false
    }

    private func save() {
        do {
            try text.write(to: fileURL, atomically: true, encoding: .utf8)
            dirty = false
            error = nil
            let episode = episode
            let key = contentKey
            let body = text
            Task {
                if key == "social" {
                    for (platform, post) in GenerationService.parseSocialPosts(body) {
                        await model.pushContent(episode: episode, key: ContentKey.social(platform), body: post)
                    }
                } else {
                    await model.pushContent(episode: episode, key: key, body: body)
                }
            }
        } catch {
            self.error = error.localizedDescription
        }
    }
}
