import SwiftUI
import UniformTypeIdentifiers

struct NewEpisodeView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss

    private enum Picking {
        case video, transcript
    }

    @State private var number = ""
    @State private var title = ""
    @State private var type: EpisodeType = .zencastr
    @State private var video: URL?
    @State private var transcript: URL?
    @State private var picking: Picking?
    @State private var error: String?
    @State private var creating = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Neue Episode").font(.title2.weight(.semibold))

            Form {
                TextField("Nummer", text: $number)
                TextField("Titel", text: $title)
                Picker("Art der Folge", selection: $type) {
                    ForEach(EpisodeType.allCases) { Text($0.label).tag($0) }
                }
                Text(type.hint).font(.caption).foregroundStyle(.secondary)

                fileRow(label: "Fertiges Video", url: video) { picking = .video }
                if type == .zencastr {
                    fileRow(label: "Transkript aus Zencastr", url: transcript) { picking = .transcript }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)

            if let error {
                Text(error).font(.callout).foregroundStyle(.red)
            }

            HStack {
                Spacer()
                Button("Abbrechen") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Anlegen") { create() }
                    .buttonStyle(GlassButtonStyle(prominent: true))
                    .keyboardShortcut(.defaultAction)
                    .disabled(creating)
            }
        }
        .padding(20)
        .frame(width: 520)
        .onAppear { if number.isEmpty { number = model.nextEpisodeNumber } }
        .fileImporter(
            isPresented: Binding(get: { picking != nil }, set: { if !$0 { picking = nil } }),
            allowedContentTypes: picking == .video ? [.movie, .video, .mpeg4Movie, .quickTimeMovie] : [.plainText, .text, .data]
        ) { result in
            guard let kind = picking, case .success(let url) = result else { return }
            switch kind {
            case .video: video = url
            case .transcript: transcript = url
            }
        }
    }

    private func fileRow(label: String, url: URL?, pick: @escaping () -> Void) -> some View {
        LabeledContent(label) {
            HStack {
                Text(url?.lastPathComponent ?? "Keine Datei gewählt")
                    .foregroundStyle(url == nil ? .secondary : .primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Button("Auswählen …", action: pick)
            }
        }
    }

    private func create() {
        creating = true
        error = nil
        Task {
            defer { creating = false }
            let scopedTranscript = transcript?.startAccessingSecurityScopedResource() ?? false
            defer { if scopedTranscript { transcript?.stopAccessingSecurityScopedResource() } }
            do {
                try await model.createEpisode(
                    number: number, title: title, type: type,
                    video: video, transcript: type == .zencastr ? transcript : nil)
                dismiss()
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
}
