import AppKit
import AVFoundation

class AppDelegate: NSObject, NSApplicationDelegate {
    private var appState: AppState?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon - menu bar app only
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationWillTerminate(_ notification: Notification) {
        appState?.shutdown()
    }

    func setAppState(_ state: AppState) {
        self.appState = state

        // Skip audio initialization during tests
        guard !isRunningTests else { return }

        Task {
            await state.start()
        }
    }

    private var isRunningTests: Bool {
        NSClassFromString("XCTestCase") != nil
    }
}
