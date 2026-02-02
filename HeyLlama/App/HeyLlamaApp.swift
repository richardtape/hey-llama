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

        // Onboarding window (opens automatically if no speakers enrolled)
        Window("Welcome to Hey Llama", id: "onboarding") {
            OnboardingView()
                .environmentObject(appState)
                .onDisappear {
                    appState.completeOnboarding()
                    Task {
                        await appState.start()
                    }
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)

        // Enrollment window for adding speakers later
        Window("Add Speaker", id: "enrollment") {
            EnrollmentView()
                .environmentObject(appState)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }
}
