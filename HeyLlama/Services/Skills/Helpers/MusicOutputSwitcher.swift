import Foundation

enum MusicOutputSwitcher {
    static func attemptSwitchIfConfigured() async -> String? {
        let config = ConfigStore().loadConfig()
        guard config.audio.autoSwitchOutputForMusic,
              let uid = config.audio.preferredOutputDeviceUID else {
            return nil
        }

        let didSwitch = AudioOutputDeviceHelper.setDefaultOutputDevice(uid: uid)
        if didSwitch {
            return nil
        }

        return await MainActor.run {
            MusicOutputWarningCenter.shared.failureMessage()
        }
    }
}
