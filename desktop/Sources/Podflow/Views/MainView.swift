import SwiftUI

struct MainView: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var presets: PresetStore

    @State private var showOnboarding = false
    @State private var showSettings = false
    @State private var showNewEpisode = false
    @State private var showPrompts = false
    @State private var showPresets = false

    var body: some View {
        NavigationSplitView {
            EpisodeListView()
                .navigationSplitViewColumnWidth(min: 240, ideal: 290)
        } detail: {
            ZStack {
                Theme.backdrop
                if let episode = model.selectedEpisode {
                    EpisodeDetailView(episode: episode)
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
                .help("Backend-Status aktualisieren")

                Button {
                    showNewEpisode = true
                } label: {
                    Label("Neue Episode", systemImage: "plus")
                }
                .help("Neue Episode anlegen")

                Menu {
                    Button("Prompts bearbeiten…") { showPrompts = true }
                    Button("Presets verwalten…") { showPresets = true }
                    Divider()
                    Button("Onboarding erneut ausführen…") { showOnboarding = true }
                    Button("Einstellungen…") { showSettings = true }
                } label: {
                    Label("Mehr", systemImage: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showOnboarding) {
            OnboardingView()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showNewEpisode) {
            NewEpisodeView()
        }
        .sheet(isPresented: $showPrompts) {
            PromptEditorView()
        }
        .sheet(isPresented: $showPresets) {
            PresetManagerView()
        }
        .alert("Patreon nicht vergessen", isPresented: $model.showPatreonReminder) {
            Button("Erledigt", role: .cancel) {}
        } message: {
            Text("Publish erfolgreich. Die Episode muss noch manuell auf Patreon hochgeladen werden.")
        }
        .task {
            if !settings.onboardingCompleted {
                showOnboarding = true
            }
            await model.refresh()
        }
    }

    private var emptyDetail: some View {
        VStack(spacing: 12) {
            Image(systemName: "waveform")
                .font(.system(size: 42))
                .foregroundStyle(Theme.accent)
            if settings.storageRootURL == nil {
                Text("Kein Episoden-Ordner gewählt")
                    .font(.title3.weight(.semibold))
                Text("Lege den Speicherort in den Einstellungen oder im Onboarding fest.")
                    .foregroundStyle(.secondary)
                Button("Einstellungen öffnen") { showSettings = true }
                    .buttonStyle(GlassButtonStyle(prominent: true))
            } else {
                Text("Keine Episode ausgewählt")
                    .font(.title3.weight(.semibold))
                Text("Wähle links eine Episode oder lege eine neue an.")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(40)
        .glassPanel()
    }

    private var connectionIndicator: some View {
        let (symbol, color, help): (String, Color, String) = switch model.connection {
        case .connected: ("checkmark.icloud", .green, "Mit Backend verbunden")
        case .authError: ("xmark.icloud", .red, "Workspace-Key abgelehnt — Einstellungen prüfen")
        case .offline: ("icloud.slash", .orange, "Backend nicht erreichbar")
        case .unconfigured: ("icloud", .secondary, "Backend nicht konfiguriert")
        }
        return Image(systemName: symbol)
            .foregroundStyle(color)
            .help(help)
    }
}
