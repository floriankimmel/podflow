import SwiftUI

@main
struct PodflowApp: App {
    @StateObject private var settings = SettingsStore.shared
    @StateObject private var model = AppModel(settings: SettingsStore.shared)

    var body: some Scene {
        WindowGroup("Podflow") {
            MainView()
                .environmentObject(settings)
                .environmentObject(model)
                .frame(minWidth: 960, minHeight: 640)
        }
        .windowStyle(.automatic)

        // Standard settings window: "Einstellungen…" in the app menu, ⌘,
        Settings {
            SettingsView()
                .environmentObject(settings)
                .environmentObject(model)
        }
    }
}
