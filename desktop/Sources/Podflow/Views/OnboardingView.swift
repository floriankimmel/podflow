import SwiftUI

/// Guided setup: installs Claude Code if missing, signs in, collects the
/// shared accounts. No terminal needed.
struct OnboardingView: View {
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var busy: String?
    @State private var error: String?

    private var claudeReady: Bool { model.claudeStatus == .ready }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Podflow einrichten").font(.title2.weight(.semibold))

            claudeSection

            Form { AccountFields() }
                .formStyle(.grouped)
                .scrollContentBackground(.hidden)

            if !settings.missingForRun.isEmpty {
                Text("Es fehlt noch: \(settings.missingForRun.joined(separator: ", "))")
                    .font(.caption).foregroundStyle(.secondary)
            }

            HStack {
                Spacer()
                Button("Später") { dismiss() }
                Button("Fertig") {
                    settings.onboardingCompleted = true
                    Task { await model.refresh() }
                    dismiss()
                }
                .buttonStyle(GlassButtonStyle(prominent: true))
                .disabled(!claudeReady || !settings.missingForRun.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 560, height: 720)
        .task { await model.refreshClaudeStatus() }
    }

    private var claudeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: claudeReady ? "checkmark.circle.fill" : "circle.dashed")
                    .foregroundStyle(claudeReady ? .green : .secondary)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Claude").font(.headline)
                    Text(claudeText).font(.callout).foregroundStyle(.secondary)
                }
                Spacer()
                if let busy {
                    ProgressView().controlSize(.small)
                    Text(busy).font(.caption).foregroundStyle(.secondary)
                } else {
                    switch model.claudeStatus {
                    case .missing:
                        Button("Installieren") { install() }.buttonStyle(GlassButtonStyle(prominent: true))
                    case .loggedOut:
                        Button("Anmelden") { login() }.buttonStyle(GlassButtonStyle(prominent: true))
                    case .ready, .none:
                        EmptyView()
                    }
                }
            }
            if let error {
                Text(error).font(.caption).foregroundStyle(.red).textSelection(.enabled)
            }
        }
        .padding(14)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
    }

    private var claudeText: String {
        switch model.claudeStatus {
        case .none: return "Wird geprüft …"
        case .missing: return "Claude Code erledigt die Arbeit im Hintergrund und muss einmal installiert werden."
        case .loggedOut: return "Bitte mit deinem Claude-Konto anmelden. Es öffnet sich der Browser."
        case .ready: return "Installiert und angemeldet."
        }
    }

    private func install() {
        perform("Wird installiert …") {
            try await model.setup.install()
        }
    }

    private func login() {
        perform("Warte auf die Anmeldung im Browser …") {
            try await model.setup.login()
        }
    }

    private func perform(_ label: String, _ work: @escaping () async throws -> Void) {
        busy = label
        error = nil
        Task {
            do {
                try await work()
            } catch {
                self.error = error.localizedDescription
            }
            await model.refreshClaudeStatus()
            busy = nil
        }
    }
}
