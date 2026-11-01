import Foundation
import Yams

/// A named snapshot of a complete podflow configuration (config-presets spec).
struct Preset: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var name: String
    var detail: String?
    var isDefault: Bool
    var configuration: PodflowConfig

    init(id: UUID = UUID(), name: String, detail: String? = nil, isDefault: Bool = false, configuration: PodflowConfig) {
        self.id = id
        self.name = name
        self.detail = detail
        self.isDefault = isDefault
        self.configuration = configuration
    }
}

/// A shareable bundle of presets (export/import, tasks 4.x).
struct PresetBundle: Codable {
    var version: Int = 1
    var presets: [Preset]
}

enum PresetError: LocalizedError {
    case invalidConfiguration(String)
    case missingEnvVariables([String])
    case lastPresetUndeletable

    var errorDescription: String? {
        switch self {
        case .invalidConfiguration(let reason):
            return "Preset ist keine gültige podflow-Konfiguration: \(reason)"
        case .missingEnvVariables(let names):
            return "Fehlende Umgebungsvariablen: \(names.joined(separator: ", "))"
        case .lastPresetUndeletable:
            return "Das letzte Preset kann nicht gelöscht werden."
        }
    }
}

/// Persisted preset library. Presets never store resolved secrets: `{{env.*}}`
/// references stay verbatim (D4).
@MainActor
final class PresetStore: ObservableObject {
    @Published private(set) var presets: [Preset] = []

    private let storeURL: URL
    private let fileManager = FileManager.default

    init(directory: URL? = nil) {
        let dir = directory ?? Self.defaultDirectory()
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        storeURL = dir.appendingPathComponent("presets.json")
        load()
    }

    static func defaultDirectory() -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Podflow", isDirectory: true)
    }

    var defaultPreset: Preset? {
        presets.first(where: \.isDefault) ?? presets.first
    }

    func preset(id: UUID?) -> Preset? {
        guard let id else { return nil }
        return presets.first { $0.id == id }
    }

    // MARK: Library mutations

    func add(_ preset: Preset) {
        var preset = preset
        if presets.isEmpty { preset.isDefault = true }
        presets.append(preset)
        save()
    }

    func update(_ preset: Preset) {
        guard let index = presets.firstIndex(where: { $0.id == preset.id }) else { return }
        presets[index] = preset
        save()
    }

    func duplicate(_ preset: Preset) {
        var copy = preset
        copy.id = UUID()
        copy.name = preset.name + " Kopie"
        copy.isDefault = false
        presets.append(copy)
        save()
    }

    func delete(_ preset: Preset) throws {
        guard presets.count > 1 else { throw PresetError.lastPresetUndeletable }
        presets.removeAll { $0.id == preset.id }
        // A default must always exist: promote the first preset.
        if !presets.contains(where: \.isDefault), var first = presets.first {
            first.isDefault = true
            presets[0] = first
        }
        save()
    }

    func setDefault(_ preset: Preset) {
        presets = presets.map { entry in
            var entry = entry
            entry.isDefault = entry.id == preset.id
            return entry
        }
        save()
    }

    // MARK: Capture from config.yml

    /// Reads an existing working config.yml and saves it as a named preset.
    /// Placeholders and `{{env.*}}` references are preserved exactly.
    @discardableResult
    func captureFromConfigFile(at url: URL, name: String, detail: String? = nil) throws -> Preset {
        let text = try String(contentsOf: url, encoding: .utf8)
        let configuration = try Self.parseConfiguration(text)
        let preset = Preset(name: name, detail: detail, configuration: configuration)
        add(preset)
        // add() may have promoted it to default: return the stored version.
        return presets.first { $0.id == preset.id } ?? preset
    }

    nonisolated static func parseConfiguration(_ yaml: String) throws -> PodflowConfig {
        do {
            let decoder = YAMLDecoder()
            return try decoder.decode(PodflowConfig.self, from: yaml)
        } catch {
            throw PresetError.invalidConfiguration(String(describing: error))
        }
    }

    nonisolated static func serializeConfiguration(_ config: PodflowConfig) throws -> String {
        let encoder = YAMLEncoder()
        return try encoder.encode(config)
    }

    // MARK: Export / import bundle

    func exportBundle(presets selection: [Preset]? = nil) throws -> Data {
        let bundle = PresetBundle(presets: selection ?? presets)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(bundle)
    }

    /// Imports a bundle. ID collisions get a fresh id, name collisions get an
    /// "(importiert)" suffix — nothing is overwritten (task 4.2).
    func importBundle(_ data: Data) throws {
        let bundle = try JSONDecoder().decode(PresetBundle.self, from: data)
        for var preset in bundle.presets {
            if presets.contains(where: { $0.id == preset.id }) {
                preset.id = UUID()
            }
            if presets.contains(where: { $0.name == preset.name }) {
                preset.name += " (importiert)"
            }
            preset.isDefault = false
            if presets.isEmpty { preset.isDefault = true }
            presets.append(preset)
        }
        if !presets.contains(where: \.isDefault), var first = presets.first {
            first.isDefault = true
            presets[0] = first
        }
        save()
    }

    // MARK: Validation (task 7.x)

    /// A preset must parse into a complete configuration before application.
    func validate(_ preset: Preset) throws {
        let yaml = try Self.serializeConfiguration(preset.configuration)
        _ = try Self.parseConfiguration(yaml)
        if preset.configuration.steps?.isEmpty != false {
            throw PresetError.invalidConfiguration("Keine Steps konfiguriert")
        }
    }

    /// Missing `{{env.*}}` variables for a preset, surfaced before a run.
    func missingEnvVariables(for preset: Preset, environment: [String: String] = ProcessInfo.processInfo.environment) -> [String] {
        preset.configuration.referencedEnvVariables
            .filter { environment[$0] == nil }
            .sorted()
    }

    // MARK: Persistence

    private func load() {
        guard let data = try? Data(contentsOf: storeURL),
              let stored = try? JSONDecoder().decode([Preset].self, from: data) else { return }
        presets = stored
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(presets) {
            try? data.write(to: storeURL)
        }
    }
}
