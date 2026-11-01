import SwiftUI

@main
struct PodflowApp: App {
    @StateObject private var settings = SettingsStore.shared
    @StateObject private var model: AppModel
    @StateObject private var presets: PresetStore

    init() {
        let presetStore = PresetStore()
        _presets = StateObject(wrappedValue: presetStore)
        _model = StateObject(wrappedValue: AppModel(settings: SettingsStore.shared, presets: presetStore))
    }

    var body: some Scene {
        WindowGroup("Podflow") {
            MainView()
                .environmentObject(settings)
                .environmentObject(model)
                .environmentObject(presets)
                .frame(minWidth: 900, minHeight: 600)
        }
        .windowStyle(.automatic)
    }
}
