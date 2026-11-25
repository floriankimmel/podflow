import SwiftUI

struct EpisodeDetailView: View {
    let episode: Episode

    @EnvironmentObject var model: AppModel
    @EnvironmentObject var settings: SettingsStore
    @State private var deleting: Episode?

    private var running: Bool { model.isRunning(episode) }
    private var phase: EpisodePhase { episode.phase }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ScrollView {
                FlowView(episode: episode)
                    .padding(16)
            }
            .frame(width: 260)
            .glassPanel()

            VStack(alignment: .leading, spacing: 12) {
                header
                if let error = model.lastError, model.selectedEpisodeNumber == episode.id {
                    errorBanner(error)
                }
                content
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(16)
        .deleteEpisodeDialog(episode: $deleting)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("#\(episode.number)")
                .font(.title2.monospacedDigit().weight(.bold))
                .foregroundStyle(Theme.accent)
            Text(episode.title.isEmpty ? "Ohne Titel" : episode.title)
                .font(.title2.weight(.semibold))
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer()
            if let type = episode.state?.type {
                Text(type.label)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.quaternary, in: Capsule())
            }
            if !running {
                Menu {
                    Button("Episode löschen …", role: .destructive) { deleting = episode }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .help("Weitere Aktionen")
            }
        }
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
            Text(message)
                .font(.callout)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(.red.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    @ViewBuilder
    private var content: some View {
        if !episode.isLocal {
            infoPanel(
                symbol: "laptopcomputer.slash",
                title: "Diese Episode liegt auf einem anderen Mac",
                text: "Du siehst hier den Fortschritt. Bearbeiten und veröffentlichen geht nur dort, wo die Episode angelegt wurde."
            )
        } else if running, model.activeRun?.mode == .prepare || phase == .preparing || phase == .notStarted {
            progressPanel(title: "Die Episode wird vorbereitet …")
        } else {
            switch phase {
            case .notStarted:
                actionPanel(
                    title: "Bereit zum Start",
                    text: "Das Video wird zu Auphonic hochgeladen. Danach entstehen Transkript, Shownotes, Social-Media-Texte und SEO. Das dauert eine Weile — du kannst die App offen lassen.",
                    button: "Starten"
                )
            case .preparing:
                actionPanel(
                    title: episode.hasFailure ? "Ein Schritt ist fehlgeschlagen" : "Die Vorbereitung wurde unterbrochen",
                    text: "Bereits erledigte Schritte werden übersprungen. Das Video wird nicht noch einmal hochgeladen.",
                    button: episode.hasFailure ? "Erneut versuchen" : "Fortsetzen"
                )
            case .review, .publishing, .scheduled:
                if let folder = episode.folderURL {
                    ReviewView(episode: episode, folder: folder, store: model.store, releaseTime: settings.releaseTime)
                }
            }
        }
    }

    private func actionPanel(title: String, text: String, button: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.title3.weight(.semibold))
            Text(text).foregroundStyle(.secondary)
            Button(button) {
                Task { await model.startPrepare(episode) }
            }
            .buttonStyle(GlassButtonStyle(prominent: true))
            .disabled(model.activeRun != nil)
            if model.activeRun != nil {
                Text("Gerade läuft eine andere Episode.").font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel()
    }

    private func infoPanel(symbol: String, title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: symbol).font(.title3.weight(.semibold))
            Text(text).foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel()
    }

    private func progressPanel(title: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ProgressView().controlSize(.small)
                Text(title).font(.title3.weight(.semibold))
            }
            RunLogView(lines: model.runLog)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .glassPanel()
    }
}

/// Live log of a headless run, pinned to the newest line.
struct RunLogView: View {
    let lines: [String]

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                        Text(line)
                            .font(.caption.monospaced())
                            .foregroundStyle(line.hasPrefix("›") ? .secondary : .primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                            .id(index)
                    }
                }
            }
            .onChange(of: lines.count) {
                if let last = lines.indices.last { proxy.scrollTo(last, anchor: .bottom) }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
