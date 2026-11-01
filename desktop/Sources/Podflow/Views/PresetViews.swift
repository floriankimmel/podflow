import SwiftUI
import UniformTypeIdentifiers

// MARK: - Cutter-facing picker (config-presets D5)

/// Simple preset choice for an episode: friendly names only, no YAML.
struct PresetPickerView: View {
    @EnvironmentObject var presets: PresetStore
    var selectedID: UUID?
    var onSelect: (Preset?) -> Void

    var body: some View {
        HStack(spacing: 8) {
            Label("Preset", systemImage: "slider.horizontal.3")
                .font(.callout)
            Picker("Preset", selection: Binding(
                get: { selectedID ?? presets.defaultPreset?.id },
                set: { newValue in onSelect(presets.preset(id: newValue)) }
            )) {
                ForEach(presets.presets) { preset in
                    Text(preset.isDefault ? "\(preset.name) (Standard)" : preset.name)
                        .tag(Optional(preset.id))
                }
            }
            .labelsHidden()
            if let preset = presets.preset(id: selectedID) ?? presets.defaultPreset,
               let detail = preset.detail, !detail.isEmpty {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
    }
}

// MARK: - Owner-facing management (config-presets D5)

struct PresetManagerView: View {
    @EnvironmentObject var presets: PresetStore
    @Environment(\.dismiss) private var dismiss

    @State private var selectedID: UUID?
    @State private var editorText = ""
    @State private var editorDirty = false
    @State private var message: String?
    @State private var messageIsError = false

    private var selected: Preset? { presets.preset(id: selectedID) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Presets")
                .font(.title2.weight(.bold))

            HSplitView {
                listPane
                    .frame(minWidth: 220, maxWidth: 300)
                editorPane
                    .frame(minWidth: 380, maxWidth: .infinity)
            }

            if let message {
                Label(message, systemImage: messageIsError ? "exclamationmark.triangle.fill" : "checkmark.circle")
                    .foregroundStyle(messageIsError ? .red : .green)
                    .font(.callout)
            }

            HStack {
                Button("Aus config.yml übernehmen…") { captureFromConfig() }
                    .buttonStyle(GlassButtonStyle())
                Button("Exportieren…") { exportBundle() }
                    .buttonStyle(GlassButtonStyle())
                    .disabled(presets.presets.isEmpty)
                Button("Importieren…") { importBundle() }
                    .buttonStyle(GlassButtonStyle())
                Spacer()
                Button("Schließen") { dismiss() }
                    .buttonStyle(GlassButtonStyle(prominent: true))
            }
        }
        .padding(20)
        .frame(width: 820, height: 620)
        .background(Theme.backdrop)
        .onAppear { selectedID = presets.defaultPreset?.id; loadEditor() }
    }

    private var listPane: some View {
        VStack(alignment: .leading, spacing: 8) {
            List(selection: $selectedID) {
                ForEach(presets.presets) { preset in
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 6) {
                            Text(preset.name)
                                .lineLimit(1)
                                .truncationMode(.tail)
                            if preset.isDefault {
                                Text("Standard")
                                    .font(.caption2)
                                    .padding(.horizontal, 4)
                                    .background(Theme.accent.opacity(0.25), in: Capsule())
                            }
                        }
                        if let detail = preset.detail, !detail.isEmpty {
                            Text(detail)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .tag(preset.id)
                }
            }
            .onChange(of: selectedID) { loadEditor() }

            HStack(spacing: 6) {
                Button {
                    presets.add(Preset(name: "Neues Preset", configuration: PodflowConfig()))
                    selectedID = presets.presets.last?.id
                    loadEditor()
                } label: { Image(systemName: "plus") }
                Button {
                    if let selected { presets.duplicate(selected); }
                } label: { Image(systemName: "plus.square.on.square") }
                    .disabled(selected == nil)
                Button {
                    if let selected {
                        do {
                            try presets.delete(selected)
                            selectedID = presets.defaultPreset?.id
                            loadEditor()
                        } catch { show(error.localizedDescription, isError: true) }
                    }
                } label: { Image(systemName: "minus") }
                    .disabled(selected == nil)
                Spacer()
                Button("Als Standard") {
                    if let selected { presets.setDefault(selected) }
                }
                .disabled(selected == nil || selected?.isDefault == true)
            }
            .buttonStyle(.borderless)
        }
        .padding(8)
    }

    @ViewBuilder
    private var editorPane: some View {
        if let selected {
            VStack(alignment: .leading, spacing: 8) {
                TextField("Name", text: Binding(
                    get: { selected.name },
                    set: { newValue in
                        var preset = selected
                        preset.name = newValue
                        presets.update(preset)
                    }
                ))
                .textFieldStyle(.roundedBorder)
                TextField("Beschreibung", text: Binding(
                    get: { selected.detail ?? "" },
                    set: { newValue in
                        var preset = selected
                        preset.detail = newValue.isEmpty ? nil : newValue
                        presets.update(preset)
                    }
                ))
                .textFieldStyle(.roundedBorder)

                Text("Konfiguration (YAML) — {{env.*}} bleibt erhalten, Secrets werden nie gespeichert")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextEditor(text: $editorText)
                    .font(.system(.caption, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .padding(6)
                    .glassPanel(cornerRadius: 10)
                    .onChange(of: editorText) { editorDirty = true }

                HStack {
                    if let missing = missingEnv(), !missing.isEmpty {
                        Label("Fehlende Env-Variablen: \(missing.joined(separator: ", "))",
                              systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                    Spacer()
                    Button("YAML speichern") { saveEditor() }
                        .buttonStyle(GlassButtonStyle(prominent: true))
                        .disabled(!editorDirty)
                }
            }
            .padding(8)
        } else {
            Text("Kein Preset ausgewählt")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func missingEnv() -> [String]? {
        selected.map { presets.missingEnvVariables(for: $0) }
    }

    private func loadEditor() {
        guard let selected else {
            editorText = ""
            return
        }
        editorText = (try? PresetStore.serializeConfiguration(selected.configuration)) ?? ""
        editorDirty = false
    }

    private func saveEditor() {
        guard var preset = selected else { return }
        do {
            preset.configuration = try PresetStore.parseConfiguration(editorText)
            presets.update(preset)
            editorDirty = false
            show("Preset gespeichert.", isError: false)
        } catch {
            show(error.localizedDescription, isError: true)
        }
    }

    private func captureFromConfig() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType.yaml, UTType.plainText].compactMap { $0 }
        panel.directoryURL = URL(fileURLWithPath: NSHomeDirectory() + "/.config/podflow")
        panel.message = "Bestehende podflow config.yml als Preset übernehmen"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let preset = try presets.captureFromConfigFile(
                at: url, name: url.deletingPathExtension().lastPathComponent)
            selectedID = preset.id
            loadEditor()
            show("Konfiguration als Preset übernommen.", isError: false)
        } catch {
            show(error.localizedDescription, isError: true)
        }
    }

    private func exportBundle() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "podflow-presets.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try presets.exportBundle().write(to: url)
            show("Preset-Bundle exportiert.", isError: false)
        } catch {
            show(error.localizedDescription, isError: true)
        }
    }

    private func importBundle() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try presets.importBundle(Data(contentsOf: url))
            show("Preset-Bundle importiert.", isError: false)
        } catch {
            show(error.localizedDescription, isError: true)
        }
    }

    private func show(_ text: String, isError: Bool) {
        message = text
        messageIsError = isError
    }
}
