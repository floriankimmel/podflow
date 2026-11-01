import SwiftUI

struct EpisodeDetailView: View {
    let episode: Episode
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var presets: PresetStore

    @State private var showContentEditor: String?
    @State private var videoURL: URL?
    @State private var awaitingAudio = false

    private var record: BackendEpisode? { model.backendRecord(for: episode) }
    private var folder: URL? { episode.local?.folderURL }

    /// The episode's selected preset (app metadata), else the default preset.
    private var presetConfig: PodflowConfig? {
        var id: UUID?
        if let folder {
            id = model.discovery.readAppMetadata(from: folder)
                .presetID.flatMap(UUID.init(uuidString:))
        }
        return (presets.preset(id: id) ?? presets.defaultPreset)?.configuration
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Pipeline")
                            .font(.headline)
                        FlowView(
                            stages: episode.profile.stages(
                                configuredPublish: presetConfig?.configuredPublishSteps),
                            record: record,
                            localDone: episode.local?.doneSteps ?? []
                        )
                        if let refreshed = model.lastRefreshed {
                            Text("Stand: \(refreshed.formatted(date: .omitted, time: .standard))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(16)
                    .frame(minWidth: 230, alignment: .leading)
                    .glassPanel()

                    VStack(alignment: .leading, spacing: 16) {
                        actionsPanel
                        readinessPanel
                        contentPanel
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                if !model.actionLog.isEmpty {
                    logPanel
                }
                if let error = model.lastError {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .padding(12)
                        .glassPanel(cornerRadius: 12)
                }
            }
            .padding(20)
        }
        .sheet(item: $showContentEditor) { key in
            if let folder {
                MarkdownEditorView(episode: episode, contentKey: key, episodeFolder: folder)
            }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            if let number = episode.displayNumber {
                Text("#\(number)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.accent)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(episode.displayTitle)
                    .font(.title2.weight(.semibold))
                    .lineLimit(2)
                    .truncationMode(.tail)
                HStack(spacing: 8) {
                    if let date = episode.releaseDate, !date.isEmpty {
                        Label(date, systemImage: "calendar")
                    }
                    Menu {
                        ForEach(EpisodeProfile.all) { profile in
                            Button(profile.displayName) { setProfile(profile.id) }
                        }
                    } label: {
                        Label(episode.profile.displayName,
                              systemImage: "point.3.connected.trianglepath.dotted")
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    .disabled(folder == nil)
                    if episode.local == nil {
                        Label("nur Backend", systemImage: "icloud")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    // MARK: Actions

    @ViewBuilder
    private var actionsPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Aktionen").font(.headline)
                Spacer()
                if model.runningAction != nil {
                    ProgressView().controlSize(.small)
                }
            }

            if let folder {
                presetRow(folder: folder)

                if episode.profileID == "video" || episode.profile.id == "video" {
                    videoActions(folder: folder)
                }

                if episode.profile.id == "studio",
                   !model.discovery.hasFinishedAudio(in: folder) {
                    Label("Wartet auf geschnittenes Audio (mp3 + m4a aus Reaper)",
                          systemImage: "scissors")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                HStack(spacing: 8) {
                    actionButton("Transkribieren", step: "transcribe") {
                        await model.runTranscription(for: episode)
                    }
                    actionButton("Shownotes", step: "shownotes") {
                        await model.runGeneration("shownotes", for: episode)
                    }
                    actionButton("Social", step: "social") {
                        await model.runGeneration("social", for: episode)
                    }
                    actionButton("SEO", step: "seo") {
                        await model.runGeneration("seo", for: episode)
                    }
                }

                Button {
                    Task { await model.runPublish(for: episode) }
                } label: {
                    Label("Publish starten", systemImage: "paperplane.fill")
                }
                .buttonStyle(GlassButtonStyle(prominent: true))
                .disabled(model.runningAction != nil)
            } else {
                Text("Diese Episode existiert nur im Backend — kein lokaler Ordner im Speicherort.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .glassPanel()
    }

    private func actionButton(_ title: String, step: String, action: @escaping () async -> Void) -> some View {
        Button {
            Task { await action() }
        } label: {
            if model.runningAction == step {
                HStack(spacing: 4) {
                    ProgressView().controlSize(.mini)
                    Text(title)
                }
            } else {
                Text(title)
            }
        }
        .buttonStyle(GlassButtonStyle())
        .disabled(model.runningAction != nil)
        .contextMenu {
            Button("Neu generieren (überschreiben)") {
                Task {
                    if step == "transcribe" {
                        await model.runTranscription(for: episode, force: true)
                    } else {
                        await model.runGeneration(step, for: episode, force: true)
                    }
                }
            }
        }
    }

    private func setProfile(_ id: String) {
        guard let folder else { return }
        var meta = model.discovery.readAppMetadata(from: folder)
        meta.profile = id
        try? model.discovery.writeAppMetadata(meta, to: folder)
        Task { await model.refresh() }
    }

    private func presetRow(folder: URL) -> some View {
        let meta = model.discovery.readAppMetadata(from: folder)
        let selectedID = meta.presetID.flatMap(UUID.init(uuidString:))
        return PresetPickerView(selectedID: selectedID) { preset in
            var meta = model.discovery.readAppMetadata(from: folder)
            meta.presetID = preset?.id.uuidString
            try? model.discovery.writeAppMetadata(meta, to: folder)
            Task { await model.refresh() }
        }
    }

    @ViewBuilder
    private func videoActions(folder: URL) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Button {
                    pickVideoAndStart(folder: folder)
                } label: {
                    Label("Video zu Auphonic", systemImage: "video.badge.waveform")
                }
                .buttonStyle(GlassButtonStyle())
                .disabled(model.runningAction != nil)

                Button {
                    Task { await downloadProducedAudio(folder: folder) }
                } label: {
                    Label("Audio vom Server laden", systemImage: "arrow.down.circle")
                }
                .buttonStyle(GlassButtonStyle())
                .disabled(model.runningAction != nil)
            }
            if awaitingAudio {
                Label("Wartet auf produziertes Audio vom Server…", systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }

    private func pickVideoAndStart(folder: URL) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.movie, .mpeg4Movie, .quickTimeMovie]
        panel.allowsMultipleSelection = false
        panel.message = "Fertig geschnittenes Video für Auphonic wählen"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        videoURL = url
        Task { await startAuphonicProduction(videoURL: url, folder: folder) }
    }

    private func startAuphonicProduction(videoURL: URL, folder: URL) async {
        model.runningAction = "auphonic_production"
        model.lastError = nil
        defer { model.runningAction = nil }
        await model.report(episode: episode, step: "video", status: .done)
        await model.report(episode: episode, step: "auphonic_production", status: .inProgress)
        do {
            let config = presets.defaultPreset?.configuration
            let auphonicConfig = config?.steps?.compactMap(\.auphonic).first
            let client = AuphonicClient(
                username: resolveEnv(auphonicConfig?.username ?? ""),
                password: resolveEnv(auphonicConfig?.password ?? "")
            )
            // Push the generated YouTube description when it already exists (D4).
            let seoURL = GenerationService.seoURL(
                episodeFolder: folder, config: config, episodeNumber: episode.episodeNumber)
            let seo = try? String(contentsOf: seoURL, encoding: .utf8)
            let youtubeDescription = seo.flatMap(GenerationService.youtubeDescription(fromSEO:))

            let production = try await client.createProduction(
                preset: auphonicConfig?.preset ?? "",
                title: episode.displayTitle,
                youtubeDescription: youtubeDescription
            )
            try await client.uploadVideo(productionUUID: production.uuid, fileURL: videoURL)
            try await client.startProduction(productionUUID: production.uuid)
            await model.report(episode: episode, step: "auphonic_production", status: .done)
            await model.report(episode: episode, step: "download_audio", status: .pending)
        } catch {
            model.lastError = error.localizedDescription
            await model.report(episode: episode, step: "auphonic_production", status: .failed)
        }
    }

    private func downloadProducedAudio(folder: URL) async {
        model.runningAction = "download_audio"
        model.lastError = nil
        defer { model.runningAction = nil }
        await model.report(episode: episode, step: "download_audio", status: .inProgress)
        let downloader = ServerAudioDownloader()
        do {
            let state = try await downloader.attemptDownload(
                template: settings.audioServerURLTemplate,
                episodeFolder: folder,
                episodeNumber: episode.episodeNumber
            )
            switch state {
            case .downloaded:
                awaitingAudio = false
                await model.report(episode: episode, step: "download_audio", status: .done)
            case .awaitingProducedAudio:
                awaitingAudio = true
                await model.report(episode: episode, step: "download_audio", status: .inProgress)
            }
        } catch {
            model.lastError = error.localizedDescription
            await model.report(episode: episode, step: "download_audio", status: .failed)
        }
    }

    private func resolveEnv(_ value: String) -> String {
        var result = value
        if let range = result.range(of: #"\{\{env\.([A-Za-z0-9_]+)\}\}"#, options: .regularExpression) {
            let token = String(result[range])
            let name = token.dropFirst(6).dropLast(2)
            result = result.replacingCharacters(
                in: range, with: ProcessInfo.processInfo.environment[String(name)] ?? "")
        }
        return result
    }

    // MARK: Readiness

    @ViewBuilder
    private var readinessPanel: some View {
        if let folder {
            let config = presets.defaultPreset?.configuration
            let items = model.readiness.check(
                episodeFolder: folder, episodeNumber: episode.episodeNumber, config: config)
            VStack(alignment: .leading, spacing: 8) {
                Text("Publish-Bereitschaft").font(.headline)
                ForEach(items) { item in
                    HStack(spacing: 6) {
                        Image(systemName: item.present ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(item.present ? .green : .secondary)
                        Text(item.name)
                        Text(item.fileName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                    }
                    .font(.callout)
                }
            }
            .padding(16)
            .glassPanel()
        }
    }

    // MARK: Content

    @ViewBuilder
    private var contentPanel: some View {
        if folder != nil {
            VStack(alignment: .leading, spacing: 8) {
                Text("Inhalte").font(.headline)
                HStack(spacing: 8) {
                    contentButton("Transkript", key: ContentKey.transcript)
                    contentButton("Shownotes", key: ContentKey.shownotes)
                    contentButton("Social", key: "social")
                    contentButton("SEO", key: ContentKey.seo)
                }
            }
            .padding(16)
            .glassPanel()
        }
    }

    private func contentButton(_ title: String, key: String) -> some View {
        Button(title) { showContentEditor = key }
            .buttonStyle(GlassButtonStyle())
    }

    // MARK: Log

    private var logPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("podflow Ausgabe").font(.headline)
            ScrollView {
                Text(model.actionLog)
                    .font(.system(.caption, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .frame(maxHeight: 180)
        }
        .padding(16)
        .glassPanel()
    }
}

extension String: @retroactive Identifiable {
    public var id: String { self }
}
