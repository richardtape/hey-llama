import Foundation

struct AudioConfig: Codable, Equatable, Sendable {
    var preferredOutputDeviceUID: String?
    var autoSwitchOutputForMusic: Bool

    init(preferredOutputDeviceUID: String? = nil, autoSwitchOutputForMusic: Bool = true) {
        self.preferredOutputDeviceUID = preferredOutputDeviceUID
        self.autoSwitchOutputForMusic = autoSwitchOutputForMusic
    }
}
