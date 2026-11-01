import SwiftUI

/// Markdown editor for the three generation prompts (design D4): edits persist
/// in Application Support and are used on the next run.
struct PromptEditorView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var selected: PromptStore.Prompt = .shownotes
    @State private var text = ""
    @State private var dirty = false
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Prompts")
                    .font(.title2.weight(.bold))
                Spacer()
                if model.promptStore.isEdited(selected) {
                    Text("angepasst")
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .background(Theme.accent.opacity(0.2), in: Capsule())
                }
            }

            Picker("Prompt", selection: $selected) {
                ForEach(PromptStore.Prompt.allCases) { prompt in
                    Text(prompt.displayName).tag(prompt)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: selected) { load() }

            TextEditor(text: $text)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(8)
                .glassPanel(cornerRadius: 12)
                .onChange(of: text) { dirty = true }

            if let error {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
            }

            HStack {
                Button("Auf Standard zurücksetzen") {
                    model.promptStore.resetToBundled(selected)
                    load()
                }
                .buttonStyle(GlassButtonStyle())
                Spacer()
                Button("Schließen") { dismiss() }
                    .buttonStyle(GlassButtonStyle())
                Button("Speichern") {
                    do {
                        try model.promptStore.save(text, for: selected)
                        dirty = false
                        error = nil
                    } catch {
                        self.error = error.localizedDescription
                    }
                }
                .buttonStyle(GlassButtonStyle(prominent: true))
                .disabled(!dirty)
            }
        }
        .padding(20)
        .frame(width: 700, height: 600)
        .background(Theme.backdrop)
        .onAppear { load() }
    }

    private func load() {
        text = (try? model.promptStore.text(for: selected)) ?? ""
        dirty = false
        error = nil
    }
}
