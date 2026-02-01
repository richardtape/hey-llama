import SwiftUI

@main
struct HeyLlamaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(appState)
                .onAppear {
                    appDelegate.setAppState(appState)
                }
        } label: {
            Image(systemName: appState.statusIcon)
        }

        Settings {
            SettingsView()
                .environmentObject(appState)
        }

        Window("Speaker Enrollment", id: "enrollment") {
            EnrollmentView()
                .environmentObject(appState)
        }
    }
}
