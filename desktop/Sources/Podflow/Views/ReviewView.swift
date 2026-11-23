import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// The mandatory review between generation and publishing: edit shownotes and
/// social posts, copy the SEO parts that are entered by hand, read the
/// fact-check, then pick images and release date and publish.
struct ReviewView: View {
    let episode: Episode

    @EnvironmentObject var model: AppModel
    @EnvironmentObject var settings: SettingsStore

    enum Tab: String, CaseIterable, Identifiable {
        case shownotes = "Shownotes"
        case social = "Social Media"
        case seo = "SEO"
        case factcheck = "Faktencheck"
        case publish = "Veröffentlichen"
        var id: String { rawValue }
    }

    @State private var tab: Tab = .shownotes
    @State private var draft = ReviewDraft()
    /// The draft as last read from or written to disk; edits differ from it.
    @State private var saved = ReviewDraft()
    @State private var releaseDate = Date()
    @State private var pickingImage: EpisodeStore.ImageSlot?
    @State private var saveError: String?

    private var folder: URL? { episode.folderURL }
    private var phase: EpisodePhase { episode.phase }
    private var running: Bool { model.isRunning(episode) }
    private var editable: Bool { phase == .review && !running }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Bereich", selection: $tab) {
                ForEach(Tab.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Group {
                switch tab {
                case .shownotes: shownotesTab
                case .social: socialTab
                case .seo: seoTab
                case .factcheck: factcheckTab
                case .publish: publishTab
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(16)
        .glassPanel()
        .task { load() }
        .onChange(of: running) { if !running { load() } }
        .onChange(of: draft) { save() }
        .fileImporter(
            isPresented: Binding(get: { pickingImage != nil }, set: { if !$0 { pickingImage = nil } }),
            allowedContentTypes: [.png, .jpeg]
        ) { result in
            guard let slot = pickingImage, case .success(let url) = result else { return }
            storeImage(url, as: slot)
        }
    }

    // MARK: Tabs

    private var shownotesTab: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextEditor(text: $draft.shownotes)
                .font(.body.monospaced())
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(.background.opacity(0.6), in: RoundedRectangle(cornerRadius: 10))
                .disabled(!editable)
            HStack {
                Text(editable ? "Änderungen werden automatisch gespeichert." : "Nach dem Veröffentlichen nicht mehr änderbar.")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                CopyButton(text: draft.shownotes)
            }
        }
    }

    private var socialTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if draft.posts.isEmpty { emptyHint("Noch keine Social-Media-Texte vorhanden.") }
                ForEach($draft.posts) { $post in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(post.platform).font(.headline)
                            Spacer()
                            Text("\(post.text.count) Zeichen").font(.caption).foregroundStyle(.secondary)
                            CopyButton(text: post.text)
                        }
                        TextEditor(text: $post.text)
                            .font(.body)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 110)
                            .padding(6)
                            .background(.background.opacity(0.6), in: RoundedRectangle(cornerRadius: 10))
                    }
                    .padding(12)
                    .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    private var seoTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("Fokus-Keyword, Meta-Beschreibung und die YouTube-Texte werden automatisch eingetragen. Title Tag und Facebook-Texte bitte in WordPress einfügen.")
                    .font(.callout).foregroundStyle(.secondary)
                if draft.seo.isEmpty { emptyHint("Noch keine SEO-Texte vorhanden.") }
                ForEach(draft.seo) { section in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(section.label).font(.headline)
                            if section.isManual {
                                Text("von Hand einfügen")
                                    .font(.caption2)
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(Theme.accent.opacity(0.2), in: Capsule())
                            }
                            Spacer()
                            CopyButton(text: section.text)
                        }
                        Text(section.text)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(12)
                    .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    private var factcheckTab: some View {
        ScrollView {
            if draft.factcheck.isEmpty {
                emptyHint("Kein Faktencheck-Bericht vorhanden.")
            } else {
                Text(draft.factcheck)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var publishTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                switch phase {
                case .scheduled:
                    Label("Die Episode ist geplant und geht zum gewählten Termin online.", systemImage: "calendar.badge.checkmark")
                        .font(.title3.weight(.semibold)).foregroundStyle(.green)
                    if let url = episode.state?.youtubeURL, let link = URL(string: url) {
                        Link("Video auf YouTube öffnen", destination: link)
                    }
                    Text("Die Social-Media-Texte findest du im Reiter „Social Media“ zum Kopieren.")
                        .foregroundStyle(.secondary)
                default:
                    imageRow(title: "Cover", hint: "Erscheint in den Podcast-Apps und beim YouTube-Video.", file: draft.coverFile, slot: .cover)
                    imageRow(title: "Beitragsbild für die Website", hint: "Das Bild über dem Beitrag in WordPress.", file: draft.featuredFile, slot: .featured)
                    DatePicker("Erscheint am", selection: $releaseDate, displayedComponents: [.date, .hourAndMinute])
                        .frame(maxWidth: 360)
                        .disabled(running)

                    if running {
                        HStack(spacing: 10) {
                            ProgressView().controlSize(.small)
                            Text("Wird veröffentlicht …").font(.headline)
                        }
                        RunLogView(lines: model.runLog).frame(minHeight: 160)
                    } else {
                        VStack(alignment: .leading, spacing: 6) {
                            Button(phase == .publishing ? "Veröffentlichung fortsetzen" : "Veröffentlichen") { publish() }
                                .buttonStyle(GlassButtonStyle(prominent: true))
                                .disabled(!canPublish)
                            Text(publishHint).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                if let saveError {
                    Text(saveError).font(.caption).foregroundStyle(.red)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var canPublish: Bool {
        draft.hasImages && model.activeRun == nil
    }

    private var publishHint: String {
        if !draft.hasImages { return "Bitte zuerst beide Bilder auswählen." }
        if model.activeRun != nil { return "Gerade läuft eine andere Episode." }
        return "Das Video geht auf YouTube, das Audio auf den Server und der Beitrag wird in WordPress für den gewählten Termin geplant."
    }

    private func imageRow(title: String, hint: String, file: String?, slot: EpisodeStore.ImageSlot) -> some View {
        HStack(spacing: 12) {
            Group {
                if let file, let folder, let image = NSImage(contentsOf: folder.appendingPathComponent(file)) {
                    Image(nsImage: image).resizable().scaledToFill()
                } else {
                    Image(systemName: "photo").font(.title2).foregroundStyle(.secondary)
                }
            }
            .frame(width: 72, height: 72)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(hint).font(.caption).foregroundStyle(.secondary)
                Button(file == nil ? "Bild auswählen …" : "Anderes Bild wählen …") { pickingImage = slot }
                    .disabled(running)
            }
        }
    }

    private func emptyHint(_ text: String) -> some View {
        Text(text).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Data

    private func load() {
        guard let folder else { return }
        let loaded = model.store.loadReviewDraft(in: folder)
        saved = loaded
        draft = loaded
        releaseDate = Self.suggestedReleaseDate(time: settings.releaseTime)
    }

    /// Autosave: writes the draft whenever it differs from what is on disk.
    private func save() {
        guard editable, draft != saved, let folder else { return }
        do {
            try model.store.saveReviewDraft(draft, in: folder)
            saved = draft
            saveError = nil
        } catch {
            saveError = "Speichern fehlgeschlagen: \(error.localizedDescription)"
        }
    }

    private func storeImage(_ url: URL, as slot: EpisodeStore.ImageSlot) {
        guard let folder else { return }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            let name = try model.store.storeImage(url, as: slot, in: folder)
            switch slot {
            case .cover: draft.coverFile = name
            case .featured: draft.featuredFile = name
            }
            saved.coverFile = draft.coverFile
            saved.featuredFile = draft.featuredFile
            saveError = nil
        } catch {
            saveError = "Bild konnte nicht übernommen werden: \(error.localizedDescription)"
        }
    }

    private func publish() {
        guard let coverFile = draft.coverFile, let featuredFile = draft.featuredFile else { return }
        let review = EpisodePipeline.Review(releaseDate: releaseDate, coverFile: coverFile, featuredFile: featuredFile)
        Task { await model.startPublish(episode, review: review) }
    }

    /// Next Friday at the configured time (the podcast's release slot).
    static func suggestedReleaseDate(time: String, now: Date = Date(), calendar: Calendar = .current) -> Date {
        let parts = time.split(separator: ":").compactMap { Int($0) }
        var components = DateComponents()
        components.weekday = 6
        components.hour = parts.first ?? 9
        components.minute = parts.count > 1 ? parts[1] : 0
        return calendar.nextDate(after: now, matching: components, matchingPolicy: .nextTime) ?? now
    }
}

struct CopyButton: View {
    let text: String
    @State private var copied = false

    var body: some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            copied = true
            Task {
                try? await Task.sleep(for: .seconds(1.5))
                copied = false
            }
        } label: {
            Label(copied ? "Kopiert" : "Kopieren", systemImage: copied ? "checkmark" : "doc.on.doc")
        }
        .disabled(text.isEmpty)
    }
}
