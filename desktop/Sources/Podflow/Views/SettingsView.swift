import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Einstellungen")
                .font(.title2.weight(.bold))

            Form {
                Section("Backend") {
                    TextField("Backend-URL", text: $settings.backendURL,
                              prompt: Text("https://podflow-backend.fly.dev"))
                    SecureField("Workspace-Key", text: $settings.workspaceKey)
                        .help("Gemeinsamer Team-Schlüssel, gespeichert im Schlüsselbund")
                }

                Section("Episoden") {
                    HStack {
                        TextField("Episoden-Ordner", text: $settings.storageRootPath)
                            .truncationMode(.middle)
                        Button("Wählen…") {
                            let panel = NSOpenPanel()
                            panel.canChooseDirectories = true
                            panel.canChooseFiles = false
                            panel.canCreateDirectories = true
                            if panel.runModal() == .OK, let url = panel.url {
                                settings.storageRootPath = url.path
                            }
                        }
                    }
                }

                Section("Transkription & Generierung") {
                    TextField("Transkriptions-Befehl", text: $settings.transcriptionCommand)
                        .help("Platzhalter: {{audio}}, {{output}}, {{outputDir}}")
                    Picker("Generierungs-Engine", selection: $settings.generationEngine) {
                        ForEach(SettingsStore.GenerationEngine.allCases) { engine in
                            Text(engine.label).tag(engine)
                        }
                    }
                    if settings.generationEngine == .ollama {
                        TextField("Generierungs-Modell (Ollama)", text: $settings.generationModel)
                            .help("Standard: \(SettingsStore.defaultGenerationModel), auf 16GB-Maschinen \(SettingsStore.fallbackGenerationModel)")
                    }
                }

                Section("Video-Profil") {
                    TextField("Audio-Server-URL", text: $settings.audioServerURLTemplate,
                              prompt: Text("https://server/podcast/{{episodeNumber}}_{{slug}}.mp3"))
                        .help("Platzhalter: {{episodeNumber}}, {{slug}}")
                }
            }
            .formStyle(.grouped)

            HStack {
                Button("Onboarding erneut ausführen") {
                    settings.onboardingCompleted = false
                    dismiss()
                }
                .buttonStyle(GlassButtonStyle())
                Spacer()
                Button("Fertig") {
                    dismiss()
                    Task { await model.refresh() }
                }
                .buttonStyle(GlassButtonStyle(prominent: true))
            }
        }
        .padding(24)
        .frame(width: 540, height: 520)
        .background(Theme.backdrop)
    }
}
