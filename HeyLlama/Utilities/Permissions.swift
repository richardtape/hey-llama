import AVFoundation
import AppKit
import EventKit
import CoreLocation

enum Permissions {

    enum PermissionStatus: Equatable {
        case granted
        case denied
        case undetermined
    }

    // MARK: - Microphone

    static func checkMicrophoneStatus() -> PermissionStatus {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return .granted
        case .denied, .restricted:
            return .denied
        case .notDetermined:
            return .undetermined
        @unknown default:
            return .undetermined
        }
    }

    static func requestMicrophoneAccess() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .audio)
    }

    // MARK: - Reminders

    static func checkRemindersStatus() -> PermissionStatus {
        let status = EKEventStore.authorizationStatus(for: .reminder)
        switch status {
        case .fullAccess, .authorized:
            return .granted
        case .denied, .restricted:
            return .denied
        case .notDetermined, .writeOnly:
            return .undetermined
        @unknown default:
            return .undetermined
        }
    }

    static func requestRemindersAccess() async -> Bool {
        let store = EKEventStore()
        do {
            return try await store.requestFullAccessToReminders()
        } catch {
            print("Reminders permission error: \(error)")
            return false
        }
    }

    // MARK: - Location

    @MainActor
    static func checkLocationStatus() -> PermissionStatus {
        // Use the shared manager to get consistent authorization status
        return LocationPermissionRequester.shared.currentStatus
    }

    static func requestLocationAccess() async -> Bool {
        await LocationPermissionRequester.shared.requestPermission()
    }

    // MARK: - System Settings

    static func openSystemSettingsPrivacy() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
    }

    static func openSystemSettingsForPermission(_ permission: SkillPermission) {
        let key = permission.systemSettingsKey
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(key)") {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - Location Permission Requester

/// Helper class to request location permission using CLLocationManager
@MainActor
final class LocationPermissionRequester: NSObject, CLLocationManagerDelegate {
    static let shared = LocationPermissionRequester()
    static let defaultAuthorizationStatusProvider: () -> CLAuthorizationStatus = {
        CLLocationManager.authorizationStatus()
    }
    static var authorizationStatusProvider: () -> CLAuthorizationStatus = defaultAuthorizationStatusProvider

    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<Bool, Never>?

    /// Current permission status from the shared manager
    var currentStatus: Permissions.PermissionStatus {
        let status = Self.authorizationStatusProvider()
#if os(iOS) || os(tvOS) || os(watchOS)
        let isAuthorized = status == .authorizedAlways
            || status == .authorized
            || status == .authorizedWhenInUse
#else
        let isAuthorized = status == .authorizedAlways
            || status == .authorized
#endif

        if isAuthorized {
            return .granted
        }

        switch status {
        case .denied, .restricted:
            return .denied
        case .notDetermined:
            return .undetermined
        @unknown default:
            return .undetermined
        }
    }

    private override init() {
        super.init()
        manager.delegate = self
    }

    func requestPermission() async -> Bool {
        let currentStatus = Self.authorizationStatusProvider()

        // Already determined
        #if os(iOS) || os(tvOS) || os(watchOS)
        if currentStatus == .authorizedAlways || currentStatus == .authorized || currentStatus == .authorizedWhenInUse {
            return true
        }
        #else
        if currentStatus == .authorizedAlways || currentStatus == .authorized {
            return true
        }
        #endif
        if currentStatus == .denied || currentStatus == .restricted {
            return false
        }

        // Request permission and wait for delegate callback
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            manager.requestWhenInUseAuthorization()
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            guard let continuation = self.continuation else { return }
            self.continuation = nil

            switch manager.authorizationStatus {
            case .authorizedAlways, .authorized:
                continuation.resume(returning: true)
            case .denied, .restricted:
                continuation.resume(returning: false)
            case .notDetermined:
                // Still waiting, don't resume yet
                self.continuation = continuation
            @unknown default:
                continuation.resume(returning: false)
            }
        }
    }
}
