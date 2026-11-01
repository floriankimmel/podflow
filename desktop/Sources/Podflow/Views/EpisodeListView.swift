import SwiftUI

struct EpisodeListView: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var settings: SettingsStore

    var body: some View {
        List(selection: $model.selectedEpisodeID) {
            if model.episodes.isEmpty {
                emptyState
            } else {
                ForEach(model.episodes) { episode in
                    EpisodeRow(episode: episode, record: model.backendRecord(for: episode))
                        .tag(episode.id)
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Episoden")
        .onChange(of: model.selectedEpisodeID) {
            Task { await model.refreshSelected() }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if settings.storageRootURL == nil {
            Label("Kein Episoden-Ordner gewählt", systemImage: "folder.badge.questionmark")
                .foregroundStyle(.secondary)
        } else {
            Label("Keine Episoden in \(settings.storageRootPath)", systemImage: "folder")
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .truncationMode(.middle)
        }
    }
}

struct EpisodeRow: View {
    let episode: Episode
    let record: BackendEpisode?

    /// Furthest-reached or failed stage glyph for the sidebar.
    private var statusGlyph: (symbol: String, color: Color) {
        if let record {
            if record.steps.contains(where: { $0.status == .failed }) {
                return ("exclamationmark.circle.fill", .red)
            }
            if record.anyStepInProgress {
                return ("arrow.triangle.2.circlepath.circle.fill", .blue)
            }
        }
        let backendDone = record?.steps.filter { $0.status == .done }.map(\.step) ?? []
        let doneCount = Set(backendDone).union(episode.local?.doneSteps ?? []).count
        if doneCount == 0 { return ("circle.dashed", .secondary) }
        let total = episode.profile.stages.count
        return doneCount >= total
            ? ("checkmark.circle.fill", .green)
            : ("circle.bottomhalf.filled", Theme.accent)
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: statusGlyph.symbol)
                .foregroundStyle(statusGlyph.color)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    if let number = episode.displayNumber {
                        Text("#\(number)")
                            .font(.caption.monospacedDigit().weight(.bold))
                            .foregroundStyle(Theme.accent)
                    }
                    // Hard rule: titles truncate with ellipsis, never clip.
                    Text(episode.displayTitle)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                HStack(spacing: 6) {
                    if let date = episode.releaseDate, !date.isEmpty {
                        Text(date)
                    }
                    Text(episode.profile.displayName)
                        .padding(.horizontal, 5)
                        .background(.quaternary, in: Capsule())
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
            }
        }
        .padding(.vertical, 2)
        .help(episode.displayTitle)
    }
}
