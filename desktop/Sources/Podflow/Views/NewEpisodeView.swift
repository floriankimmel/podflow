import SwiftUI

/// New-episode ingest (episode-ingest spec + auphonic-video-ingest): Zencastr
/// recordings (studio profile, builds the Reaper project) or a video-first
/// episode (video profile, Auphonic up front).
struct NewEpisodeView: View {
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var profile: EpisodeProfile = .studio
    @State private var slug = ""
    @State private var zencastrSource: URL?
    @State private var working = false
    @State private var error: String?
    @State private var openReaper = true

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Neue Episode")
                .font(.title2.weight(.bold))

            Picker("Workflow", selection: $profile) {
                ForEach(EpisodeProfile.all) { profile in
                    Text(profile.displayName).tag(profile)
                }
            }
            .pickerStyle(.segmented)

            TextField("Ordnername (Slug)", text: $slug, prompt: Text("259_marathon-spezial"))
                .textFieldStyle(.roundedBorder)

            if profile.id == "studio" {
                studioSection
            } else {
                videoSection
            }

            if let error {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.callout)
            }

            HStack {
                Spacer()
                Button("Abbrechen") { dismiss() }
                    .buttonStyle(GlassButtonStyle())
                Button {
                    Task { await create() }
                } label: {
                    if working {
                        ProgressView().controlSize(.small)
                    } else {
                        Text("Episode anlegen")
                    }
                }
                .buttonStyle(GlassButtonStyle(prominent: true))
                .disabled(working || slug.isEmpty || (profile.id == "studio" && zencastrSource == nil))
            }
        }
        .padding(24)
        .frame(width: 520)
        .background(Theme.backdrop)
    }

    private var studioSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Zencastr-Aufnahmen")
                        .font(.callout.weight(.semibold))
                    Text(zencastrSource?.path ?? "Episoden-Ordner mit recording-* Unterordnern wählen (z. B. zencastr/259)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer()
                Button("Wählen…") {
                    let panel = NSOpenPanel()
                    panel.canChooseDirectories = true
                    panel.canChooseFiles = false
                    panel.message = "Zencastr-Episodenordner (enthält recording-*)"
                    panel.directoryURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
                    if panel.runModal() == .OK, let url = panel.url {
                        zencastrSource = url
                        if slug.isEmpty, let number = ZencastrIngest.episodeNumber(fromSource: url) {
                            slug = number
                        }
                    }
                }
                .buttonStyle(GlassButtonStyle())
            }
            Toggle("Reaper-Projekt nach dem Anlegen öffnen", isOn: $openReaper)
                .toggleStyle(.checkbox)
            Text("Alle recording-* Ordner werden eingesammelt, Audio nach Recordings/ kopiert und das Reaper-Projekt mit einem Track pro Sprecher erzeugt. Schnitt und Export (mp3/m4a) bleiben manuell.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .glassPanel()
    }

    private var videoSection: some View {
        Text("Es wird ein Episodenordner ohne Recordings/Reaper angelegt. Das fertige Video lädst du danach in der Episodenansicht zu Auphonic hoch; Auphonic veröffentlicht auf YouTube und liefert das Audio auf den Server.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(14)
            .glassPanel()
    }

    private func create() async {
        guard let root = settings.storageRootURL else {
            error = "Kein Episoden-Ordner konfiguriert."
            return
        }
        working = true
        error = nil
        defer { working = false }
        do {
            let discovery = model.discovery
            let folder: URL
            var episodeNumber: String?

            if profile.id == "studio" {
                guard let source = zencastrSource else { return }
                let ingest = ZencastrIngest()
                let result = try ingest.createEpisode(source: source, storageRoot: root, slug: slug)
                folder = result.episodeFolder
                episodeNumber = result.episodeNumber

                let generator = try RPPGenerator.load(overrideDirectory: nil)
                let projectURL = try await generator.writeProject(
                    episodeFolder: folder,
                    slug: slug,
                    recordings: result.copiedFiles,
                    speakerMap: .standard
                )
                if openReaper {
                    NSWorkspace.shared.open(projectURL)
                }
            } else {
                // Video profile: standard structure minus Recordings/Reaper.
                folder = root.appendingPathComponent(slug, isDirectory: true)
                guard !FileManager.default.fileExists(atPath: folder.path) else {
                    throw ZencastrIngest.IngestError.episodeFolderExists(slug)
                }
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                let digits = slug.prefix { $0.isNumber }
                episodeNumber = digits.isEmpty ? nil : String(digits)
            }

            try discovery.writeAppMetadata(
                EpisodeDiscovery.AppMetadata(profile: profile.id, presetID: model.presets.defaultPreset?.id.uuidString),
                to: folder
            )

            // Register in the backend so everyone sees the new episode.
            let identity = episodeNumber ?? slug
            if let client = model.backendClient {
                try? await client.putMetadata(id: identity, metadata: BackendMetadata(
                    episodeNumber: episodeNumber, slug: slug, title: nil, releaseDate: nil, profile: profile.id))
                try? await client.reportStep(
                    id: identity,
                    step: profile.id == "studio" ? "ingest" : "video",
                    status: profile.id == "studio" ? .done : .pending,
                    metadata: BackendMetadata(episodeNumber: episodeNumber, slug: slug, profile: profile.id)
                )
                if profile.id == "studio" {
                    try? await client.reportStep(
                        id: identity, step: "reaper", status: .inProgress,
                        metadata: BackendMetadata(episodeNumber: episodeNumber, slug: slug, profile: profile.id))
                }
            }

            await model.refresh()
            model.selectedEpisodeID = identity
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
