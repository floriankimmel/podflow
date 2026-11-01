import SwiftUI

/// Guided first-run flow (app-onboarding spec): detects/installs external
/// tools and sets the storage root. Ready to publish = podflow CLI + storage
/// root; transcription tools are staged and optional here (D9).
struct OnboardingView: View {
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss

    @StateObject private var manager: DependencyManager

    init() {
        _manager = StateObject(wrappedValue: DependencyManager(settings: SettingsStore.shared))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                Image(systemName: "figure.run")
                    .font(.system(size: 30))
                    .foregroundStyle(Theme.accent)
                VStack(alignment: .leading) {
                    Text("Willkommen bei Podflow")
                        .font(.title2.weight(.bold))
                    Text("Einrichtung für die Laufend-Entdecken-Produktion")
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                ForEach(manager.dependencies) { dependency in
                    DependencyRow(dependency: dependency) {
                        Task { await manager.install(dependency.id) }
                    }
                }
            }
            .padding(14)
            .glassPanel()

            storageRootStep

            HStack {
                readinessLine
                Spacer()
                Button("Erneut prüfen") {
                    Task { await manager.detectAll() }
                }
                .buttonStyle(GlassButtonStyle())
                Button(manager.isReadyForPublish ? "Fertig" : "Später fertigstellen") {
                    if manager.isReadyForPublish {
                        settings.onboardingCompleted = true
                    }
                    dismiss()
                    Task { await model.refresh() }
                }
                .buttonStyle(GlassButtonStyle(prominent: true))
            }
        }
        .padding(24)
        .frame(width: 560)
        .background(Theme.backdrop)
        .task { await manager.detectAll() }
    }

    private var storageRootStep: some View {
        HStack(spacing: 10) {
            Image(systemName: settings.storageRootURL != nil ? "checkmark.circle.fill" : "folder.badge.questionmark")
                .foregroundStyle(settings.storageRootURL != nil ? .green : .orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("Episoden-Ordner")
                    .font(.callout.weight(.semibold))
                Text(settings.storageRootPath.isEmpty ? "Noch nicht gewählt" : settings.storageRootPath)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            Button("Ordner wählen…") {
                let panel = NSOpenPanel()
                panel.canChooseDirectories = true
                panel.canChooseFiles = false
                panel.canCreateDirectories = true
                panel.message = "Ordner, in dem jede Episode als Unterordner liegt"
                if panel.runModal() == .OK, let url = panel.url {
                    settings.storageRootPath = url.path
                }
            }
            .buttonStyle(GlassButtonStyle())
        }
        .padding(14)
        .glassPanel()
    }

    private var readinessLine: some View {
        Group {
            if manager.isReadyForPublish {
                Label(
                    manager.allInstalled
                        ? "Bereit — alle Werkzeuge installiert"
                        : "Bereit zum Publizieren — Transkriptions-Tools optional",
                    systemImage: "checkmark.seal.fill"
                )
                .foregroundStyle(.green)
            } else {
                Label("Noch nicht bereit: podflow CLI + Episoden-Ordner nötig", systemImage: "hourglass")
                    .foregroundStyle(.orange)
            }
        }
        .font(.callout)
    }
}

private struct DependencyRow: View {
    let dependency: DependencyManager.Dependency
    let install: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            statusIcon
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(dependency.name)
                        .font(.callout.weight(.semibold))
                    if !dependency.requiredForPublish {
                        Text("optional für Publish")
                            .font(.caption2)
                            .padding(.horizontal, 5)
                            .background(.quaternary, in: Capsule())
                    }
                }
                Text(dependency.message ?? dependency.detail)
                    .font(.caption)
                    .foregroundStyle(dependency.state == .failed ? .red : .secondary)
                    .lineLimit(2)
                if dependency.state == .installing, let progress = dependency.progress {
                    ProgressView(value: progress)
                        .controlSize(.small)
                    Text("\(Int(progress * 100)) %")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            trailing
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch dependency.state {
        case .installed:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .missing:
            Image(systemName: "circle").foregroundStyle(.orange)
        case .failed:
            Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
        case .checking, .installing:
            ProgressView().controlSize(.small)
        case .unknown:
            Image(systemName: "questionmark.circle").foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var trailing: some View {
        switch dependency.state {
        case .missing, .failed:
            Button("Installieren") { install() }
                .buttonStyle(GlassButtonStyle(prominent: true))
        case .installed:
            Text("Installiert")
                .font(.caption)
                .foregroundStyle(.secondary)
        default:
            EmptyView()
        }
    }
}
