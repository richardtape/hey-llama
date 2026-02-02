import AppKit
import AVFoundation

class AppDelegate: NSObject, NSApplicationDelegate {
    private var appState: AppState?

    /// Check if we're running in a test environment
    private var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationWillTerminate(_ notification: Notification) {
        appState?.shutdown()
    }

    func setAppState(_ state: AppState) {
        self.appState = state

        // Skip initialization during tests
        guard !isRunningTests else {
            print("Running in test environment - skipping initialization")
            return
        }

        // Check if onboarding is needed
        if state.requiresOnboarding {
            // Open onboarding window
            DispatchQueue.main.async {
                if let window = NSApp.windows.first(where: { $0.title == "Welcome to Hey Llama" }) {
                    window.makeKeyAndOrderFront(nil)
                    NSApp.activate(ignoringOtherApps: true)
                } else {
                    // Try to open via SwiftUI
                    state.showOnboarding = true
                }
            }
        } else {
            // Start normally
            Task {
                await state.start()
            }
        }
    }
}
