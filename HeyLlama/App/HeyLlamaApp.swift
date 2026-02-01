import SwiftUI

@main
struct HeyLlamaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Menu bar presence
        MenuBarExtra {
            MenuBarView()
        } label: {
            Image(systemName: "waveform")
        }

        // Settings window (opened via Preferences menu item)
        Settings {
            SettingsView()
        }

        // Enrollment window (opens on demand)
        Window("Speaker Enrollment", id: "enrollment") {
            EnrollmentView()
        }
    }
}
