import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// The mandatory review between generation and publishing: edit shownotes and
/// social posts, copy the SEO parts that are entered by hand, read the
/// fact-check, then pick images and release date and publish.
struct ReviewView: View {
    let episode: Episode

    @EnvironmentObject var model: AppModel

    enum Tab: String, CaseIterable, Identifiable {
        case shownotes = "Shownotes"
        case social = "Social Media"
        case seo = "SEO"
        case factcheck = "Faktencheck"
        case publish = "Veröffentlichen"
        var id: String { rawValue }
    }

    @StateObject private var session: ReviewSession
    @State private var tab: Tab = .shownotes
    @State private var pickingImage: EpisodeStore.ImageSlot?

    init(episode: Episode, folder: URL, store: EpisodeStore, releaseTime: String) {
        self.episode = episode
        _session = StateObject(wrappedValue: ReviewSession(folder: folder, store: store, releaseTime: releaseTime))
    }

    private var phase: EpisodePhase { episode.phase }
    private var running: Bool { model.isRunning(episode) }
    private var editable: Bool { session.isEditable }
    private var runStatus: ReviewSession.RunStatus {
        ReviewSession.RunStatus(phase: phase, isRunning: running, anyRunActive: model.activeRun != nil)
    }

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
        .onAppear { session.runStatus = runStatus }
        .onChange(of: runStatus) { session.runStatus = runStatus }
        .fileImporter(
            isPresented: Binding(get: { pickingImage != nil }, set: { if !$0 { pickingImage = nil } }),
            allowedContentTypes: [.png, .jpeg]
        ) { result in
            guard let slot = pickingImage, case .success(let url) = result else { return }
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            session.pickImage(url, as: slot)
        }
    }

    // MARK: Tabs

    private var shownotesTab: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextEditor(text: $session.draft.shownotes)
                .font(.body.monospaced())
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(.background.opacity(0.6), in: RoundedRectangle(cornerRadius: 10))
                .disabled(!editable)
            HStack {
                Text(editable ? "Änderungen werden automatisch gespeichert." : "Nach dem Veröffentlichen nicht mehr änderbar.")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                CopyButton(text: session.draft.shownotes)
            }
        }
    }

    private var socialTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if session.draft.posts.isEmpty { emptyHint("Noch keine Social-Media-Texte vorhanden.") }
                ForEach($session.draft.posts) { $post in
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
                if session.draft.seo.isEmpty { emptyHint("Noch keine SEO-Texte vorhanden.") }
                ForEach(session.draft.seo) { section in
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
            if session.draft.factcheck.isEmpty {
                emptyHint("Kein Faktencheck-Bericht vorhanden.")
            } else {
                Text(session.draft.factcheck)
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
                    imageRow(title: "Cover", hint: "Erscheint in den Podcast-Apps und beim YouTube-Video.", file: session.draft.coverFile, slot: .cover)
                    imageRow(title: "Beitragsbild für die Website", hint: "Das Bild über dem Beitrag in WordPress.", file: session.draft.featuredFile, slot: .featured)
                    DatePicker("Erscheint am", selection: $session.releaseDate, displayedComponents: [.date, .hourAndMinute])
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
                                .disabled(!session.canPublish)
                            Text(session.publishHint).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                if let saveError = session.saveError {
                    Text(saveError).font(.caption).foregroundStyle(.red)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func imageRow(title: String, hint: String, file: String?, slot: EpisodeStore.ImageSlot) -> some View {
        HStack(spacing: 12) {
            Group {
                if let file, let image = NSImage(contentsOf: session.folder.appendingPathComponent(file)) {
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

    private func publish() {
        guard let review = session.publishDecisions() else { return }
        Task { await model.startPublish(episode, review: review) }
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
