import SwiftUI

/// Bound text field for a Keychain secret.
struct SecretField: View {
    let title: String
    let secret: SettingsStore.Secret
    var secure = true

    @EnvironmentObject var settings: SettingsStore

    var body: some View {
        let binding = Binding(
            get: { settings.secret(secret) },
            set: { settings.setSecret(secret, $0.trimmingCharacters(in: .whitespacesAndNewlines)) }
        )
        if secure {
            SecureField(title, text: binding)
        } else {
            TextField(title, text: binding)
        }
    }
}

/// Shared account fields, used by both onboarding and settings.
struct AccountFields: View {
    @EnvironmentObject var settings: SettingsStore

    var body: some View {
        Section("Auphonic") {
            SecretField(title: "Benutzername", secret: .auphonicUser, secure: false)
            SecretField(title: "Passwort", secret: .auphonicPassword)
            TextField("Preset-ID", text: $settings.auphonicPreset)
        }
        Section("WordPress") {
            SecretField(title: "Schlüssel", secret: .wordpressKey)
        }
        Section("Podcast-Server (FTP)") {
            SecretField(title: "Benutzername", secret: .ftpUser, secure: false)
            SecretField(title: "Passwort", secret: .ftpPassword)
        }
        Section("Gemeinsamer Status") {
            SecretField(title: "Workspace-Schlüssel", secret: .workspaceKey)
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var model: AppModel
    @State private var pickingFolder = false

    var body: some View {
        Form {
            Section("Episoden") {
                LabeledContent("Ordner") {
                    HStack {
                        Text(settings.episodesFolder)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .foregroundStyle(.secondary)
                        Button("Ändern …") { pickingFolder = true }
                    }
                }
                Text("Jede Episode bekommt dort einen eigenen Unterordner mit ihrer Nummer.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            AccountFields()
            Section("Erweitert") {
                TextField("Status-Server", text: $settings.backendURL)
                TextField("WordPress-Adresse", text: $settings.wordpressServer)
                TextField("FTP-Server", text: $settings.ftpHost)
                TextField("FTP-Port", text: $settings.ftpPort)
                TextField("Adresse der hochgeladenen Dateien", text: $settings.posterBaseURL)
                TextField("Übliche Uhrzeit der Veröffentlichung", text: $settings.releaseTime)
            }
        }
        .formStyle(.grouped)
        .frame(width: 560, height: 640)
        // Changes apply as they are typed; reconnect the shared status when the window closes.
        .onDisappear { Task { await model.refresh() } }
        .fileImporter(isPresented: $pickingFolder, allowedContentTypes: [.folder]) { result in
            if case .success(let url) = result { settings.episodesFolder = url.path }
        }
    }
}
