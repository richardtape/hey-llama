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

        // Skip audio initialization during tests
        guard !isRunningTests else {
            print("Running in test environment - skipping audio initialization")
            return
        }

        Task {
            await state.start()
        }
    }
}
