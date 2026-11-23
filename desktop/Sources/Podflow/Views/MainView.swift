import SwiftUI

struct MainView: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var settings: SettingsStore

    @State private var showOnboarding = false
    @State private var showNewEpisode = false

    var body: some View {
        NavigationSplitView {
            EpisodeListView()
                .navigationSplitViewColumnWidth(min: 240, ideal: 290)
        } detail: {
            ZStack {
                Theme.backdrop
                if let episode = model.selectedEpisode {
                    EpisodeDetailView(episode: episode)
                        .id(episode.id)
                } else {
                    emptyDetail
                }
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                connectionIndicator
                Button {
                    Task { await model.refresh() }
                } label: {
                    Label("Aktualisieren", systemImage: "arrow.clockwise")
                }
                .help("Status aktualisieren")

                Button {
                    showNewEpisode = true
                } label: {
                    Label("Neue Episode", systemImage: "plus")
                }
                .help("Neue Episode anlegen")

                Menu {
                    Button("Einrichtung erneut ausführen…") { showOnboarding = true }
                    SettingsLink { Text("Einstellungen…") }
                } label: {
                    Label("Mehr", systemImage: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showOnboarding) { OnboardingView() }
        .sheet(isPresented: $showNewEpisode) { NewEpisodeView() }
        .task {
            await model.refresh()
            await model.refreshClaudeStatus()
            // Claude Code missing or signed out: the guided setup handles it.
            if !settings.onboardingCompleted || model.claudeStatus != .ready {
                showOnboarding = true
            }
        }
    }

    private var emptyDetail: some View {
        VStack(spacing: 12) {
            Image(systemName: "waveform")
                .font(.system(size: 42))
                .foregroundStyle(Theme.accent)
            Text("Keine Episode ausgewählt")
                .font(.title3.weight(.semibold))
            Text("Wähle links eine Episode oder lege eine neue an.")
                .foregroundStyle(.secondary)
            Button("Neue Episode") { showNewEpisode = true }
                .buttonStyle(GlassButtonStyle(prominent: true))
        }
        .padding(40)
        .glassPanel()
    }

    private var connectionIndicator: some View {
        let (symbol, color, help): (String, Color, String) = switch model.connection {
        case .connected: ("checkmark.icloud", .green, "Gemeinsamer Status ist verbunden")
        case .authError: ("xmark.icloud", .red, "Workspace-Schlüssel wurde abgelehnt — Einstellungen prüfen")
        case .offline: ("icloud.slash", .orange, "Gemeinsamer Status nicht erreichbar")
        case .unconfigured: ("icloud", .secondary, "Gemeinsamer Status nicht eingerichtet")
        }
        return Image(systemName: symbol)
            .foregroundStyle(color)
            .help(help)
    }
}
