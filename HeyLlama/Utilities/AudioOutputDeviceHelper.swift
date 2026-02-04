import Foundation
import CoreAudio

struct AudioOutputDevice: Identifiable, Equatable {
    let id: AudioDeviceID
    let name: String
    let uid: String
    let isDefault: Bool

    var identifier: String { uid }
}

enum AudioOutputDeviceHelper {
    static func getOutputDevices() -> [AudioOutputDevice] {
        var devices: [AudioOutputDevice] = []
        let systemObjectID = AudioObjectID(kAudioObjectSystemObject)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(systemObjectID, &address, 0, nil, &dataSize) == noErr else {
            return []
        }

        let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = Array(repeating: AudioDeviceID(0), count: deviceCount)
        guard AudioObjectGetPropertyData(systemObjectID, &address, 0, nil, &dataSize, &deviceIDs) == noErr else {
            return []
        }

        let defaultDeviceID = getDefaultOutputDeviceID()

        for deviceID in deviceIDs {
            if !deviceHasOutput(deviceID) {
                continue
            }

            let name = getDeviceName(deviceID) ?? "Unknown"
            let uid = getDeviceUID(deviceID) ?? ""
            let isDefault = deviceID == defaultDeviceID
            devices.append(AudioOutputDevice(id: deviceID, name: name, uid: uid, isDefault: isDefault))
        }

        return devices.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    static func getDefaultOutputDeviceUID() -> String? {
        let deviceID = getDefaultOutputDeviceID()
        return getDeviceUID(deviceID)
    }

    static func setDefaultOutputDevice(uid: String) -> Bool {
        guard let deviceID = getDeviceID(for: uid) else {
            return false
        }

        var mutableDeviceID = deviceID
        let systemObjectID = AudioObjectID(kAudioObjectSystemObject)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let dataSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectSetPropertyData(systemObjectID, &address, 0, nil, dataSize, &mutableDeviceID)
        return status == noErr
    }

    // MARK: - Internal Helpers

    private static func getDefaultOutputDeviceID() -> AudioDeviceID {
        let systemObjectID = AudioObjectID(kAudioObjectSystemObject)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var deviceID = AudioDeviceID(0)
        var dataSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(systemObjectID, &address, 0, nil, &dataSize, &deviceID)
        return status == noErr ? deviceID : AudioDeviceID(0)
    }

    private static func getDeviceID(for uid: String) -> AudioDeviceID? {
        let devices = getOutputDevices()
        return devices.first { $0.uid == uid }?.id
    }

    private static func getDeviceName(_ deviceID: AudioDeviceID) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &dataSize) == noErr else {
            return nil
        }

        var name: CFString = "" as CFString
        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &dataSize, &name)
        return status == noErr ? (name as String) : nil
    }

    private static func getDeviceUID(_ deviceID: AudioDeviceID) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &dataSize) == noErr else {
            return nil
        }

        var uid: CFString = "" as CFString
        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &dataSize, &uid)
        return status == noErr ? (uid as String) : nil
    }

    private static func deviceHasOutput(_ deviceID: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &dataSize) == noErr else {
            return false
        }

        let rawPointer = UnsafeMutableRawPointer.allocate(byteCount: Int(dataSize), alignment: MemoryLayout<AudioBufferList>.alignment)
        defer { rawPointer.deallocate() }

        let bufferListPointer = rawPointer.bindMemory(to: AudioBufferList.self, capacity: 1)
        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &dataSize, bufferListPointer)
        guard status == noErr else { return false }

        let bufferList = UnsafeMutableAudioBufferListPointer(bufferListPointer)
        return bufferList.contains { $0.mNumberChannels > 0 }
    }
}
