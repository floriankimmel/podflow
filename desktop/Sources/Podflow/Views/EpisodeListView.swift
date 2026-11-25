import SwiftUI

struct EpisodeListView: View {
    @EnvironmentObject var model: AppModel
    @State private var deleting: Episode?

    var body: some View {
        List(selection: $model.selectedEpisodeNumber) {
            if model.episodes.isEmpty {
                Label("Noch keine Episoden", systemImage: "tray")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(model.episodes) { episode in
                    EpisodeRow(episode: episode, running: model.isRunning(episode))
                        .tag(episode.id)
                        .contextMenu {
                            Button("Episode löschen …", role: .destructive) { deleting = episode }
                                .disabled(model.isRunning(episode))
                        }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Episoden")
        .deleteEpisodeDialog(episode: $deleting)
    }
}

struct EpisodeRow: View {
    let episode: Episode
    let running: Bool

    private var statusGlyph: (symbol: String, color: Color, label: String) {
        if episode.hasFailure { return ("exclamationmark.circle.fill", .red, "Fehler") }
        if running || episode.hasStepInProgress {
            return ("arrow.triangle.2.circlepath.circle.fill", .blue, "läuft")
        }
        switch episode.phase {
        case .notStarted: return ("circle.dashed", .secondary, "neu")
        case .preparing, .publishing: return ("circle.bottomhalf.filled", Theme.accent, "in Arbeit")
        case .review: return ("eye.circle.fill", Theme.accent, "bereit zum Prüfen")
        case .scheduled: return ("calendar.badge.checkmark", .green, "geplant")
        case .live: return ("checkmark.circle.fill", .green, "online")
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: statusGlyph.symbol)
                .foregroundStyle(statusGlyph.color)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("#\(episode.number)")
                        .font(.caption.monospacedDigit().weight(.bold))
                        .foregroundStyle(Theme.accent)
                    Text(episode.title.isEmpty ? "Ohne Titel" : episode.title)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                HStack(spacing: 6) {
                    Text(statusGlyph.label)
                    if !episode.isLocal {
                        Text("nicht auf diesem Mac")
                            .padding(.horizontal, 5)
                            .background(.quaternary, in: Capsule())
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
        .help(episode.title)
    }
}

extension View {
    /// Confirmation before an episode folder goes to the Trash.
    func deleteEpisodeDialog(episode: Binding<Episode?>) -> some View {
        modifier(DeleteEpisodeDialog(episode: episode))
    }
}

private struct DeleteEpisodeDialog: ViewModifier {
    @Binding var episode: Episode?
    @EnvironmentObject var model: AppModel

    func body(content: Content) -> some View {
        content.confirmationDialog(
            "Episode #\(episode?.number ?? "") löschen?",
            isPresented: Binding(get: { episode != nil }, set: { if !$0 { episode = nil } }),
            titleVisibility: .visible,
            presenting: episode
        ) { episode in
            Button(episode.isLocal ? "In den Papierkorb legen" : "Entfernen", role: .destructive) {
                Task { await model.deleteEpisode(episode) }
            }
            Button("Abbrechen", role: .cancel) {}
        } message: { episode in
            Text(episode.isLocal
                ? "Der Episoden-Ordner mit Transkript und Texten kommt in den Papierkorb, und die Episode verschwindet auch beim anderen Host aus der Liste. Was schon bei Auphonic, YouTube oder WordPress ist, bleibt dort."
                : "Die Episode verschwindet aus der gemeinsamen Liste, auch beim anderen Host. Dateien auf dessen Mac und alles bei Auphonic, YouTube oder WordPress bleiben erhalten.")
        }
    }
}
