import AppKit
import AVFoundation

class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon - menu bar app only
        NSApp.setActivationPolicy(.accessory)

        // Request permissions on launch
        Task {
            await requestMicrophonePermission()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Cleanup placeholder - will be implemented in later milestones
    }

    private func requestMicrophonePermission() async {
        let granted = await AVCaptureDevice.requestAccess(for: .audio)
        if !granted {
            // User denied - they'll need to enable in System Settings
            print("Microphone permission denied")
        }
    }
}
