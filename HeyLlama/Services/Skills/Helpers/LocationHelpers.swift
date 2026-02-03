import CoreLocation
import Foundation

enum LocationHelpers {
    static func normalizeLocationToken(_ location: String?) -> String? {
        guard let location = location?.trimmingCharacters(in: .whitespacesAndNewlines),
              !location.isEmpty else {
            return nil
        }

        let normalized = location.lowercased()
        let userLocationTokens: Set<String> = [
            "user",
            "me",
            "my location",
            "current location",
            "current",
            "here",
            "local"
        ]

        return userLocationTokens.contains(normalized) ? nil : location
    }
}

/// Helper to get current location using CLLocationManager
actor LocationFetcher: NSObject {
    private var manager: CLLocationManager?
    private var continuation: CheckedContinuation<CLLocation, Error>?

    func getCurrentLocation() async throws -> CLLocation {
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation

            Task { @MainActor in
                let manager = CLLocationManager()
                manager.delegate = self
                manager.desiredAccuracy = kCLLocationAccuracyKilometer
                await self.setManager(manager)

                switch manager.authorizationStatus {
                case .authorizedAlways, .authorized:
                    manager.requestLocation()
                case .notDetermined:
                    manager.requestWhenInUseAuthorization()
                default:
                    await self.handleError(SkillError.permissionDenied(.location))
                }
            }
        }
    }

    private func setManager(_ manager: CLLocationManager) {
        self.manager = manager
    }

    fileprivate func handleLocation(_ location: CLLocation) {
        continuation?.resume(returning: location)
        continuation = nil
    }

    fileprivate func handleError(_ error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }

    fileprivate func handleAuthorizationChange(_ status: CLAuthorizationStatus) {
        switch status {
        case .authorizedAlways, .authorized:
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                let manager = await self.getManager()
                manager?.requestLocation()
            }
        case .denied, .restricted:
            handleError(SkillError.permissionDenied(.location))
        default:
            break
        }
    }

    private func getManager() -> CLLocationManager? {
        return manager
    }
}

extension LocationFetcher: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else { return }
        Task { await self.handleLocation(location) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { await self.handleError(SkillError.executionFailed("Location error: \(error.localizedDescription)")) }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { await self.handleAuthorizationChange(manager.authorizationStatus) }
    }
}

extension LocationHelpers {
    static func getCurrentLocation() async throws -> CLLocation {
        let fetcher = LocationFetcher()
        return try await fetcher.getCurrentLocation()
    }

    static func geocodeLocation(_ name: String) async throws -> CLLocation {
        let geocoder = CLGeocoder()
        do {
            let placemarks = try await geocoder.geocodeAddressString(name)
            guard let placemark = placemarks.first,
                  let location = placemark.location else {
                throw SkillError.executionFailed("Could not find location: \(name)")
            }
            return location
        } catch let error as SkillError {
            throw error
        } catch {
            throw SkillError.executionFailed("Geocoding error: \(error.localizedDescription)")
        }
    }
}
