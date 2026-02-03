# Skills Helpers Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Extract shared skills utilities into `Services/Skills/Helpers/` and update skills to use them with test coverage.

**Architecture:** Introduce three helper files (location, reminders, argument parsing) scoped to the skills layer. Skills call helpers for low-level operations while retaining orchestration and response formatting.

**Tech Stack:** Swift 5.9+, Foundation, CoreLocation, EventKit, XCTest.

---

### Task 1: Add argument parsing helper

**Files:**
- Create: `HeyLlama/Services/Skills/Helpers/SkillArgumentParsing.swift`
- Test: `HeyLlamaTests/SkillArgumentParsingTests.swift`

**Step 1: Write the failing test**
```swift
import XCTest
@testable import HeyLlama

final class SkillArgumentParsingTests: XCTestCase {
    private struct SampleArgs: Codable, Equatable {
        let name: String
    }

    func testDecodeArgumentsParsesValidJSON() throws {
        let args: SampleArgs = try SkillArgumentParsing.decodeArguments(from: "{\"name\":\"Llama\"}")
        XCTAssertEqual(args, SampleArgs(name: "Llama"))
    }

    func testDecodeArgumentsThrowsInvalidArguments() {
        XCTAssertThrowsError(try SkillArgumentParsing.decodeArguments(from: "not json")) { error in
            guard case SkillError.invalidArguments = error else {
                XCTFail("Expected invalidArguments error, got \(error)")
                return
            }
        }
    }
}
```

**Step 2: Run test to verify it fails**
Run: `Cmd+U` and confirm failures in Test Navigator for `SkillArgumentParsingTests`.

**Step 3: Write minimal implementation**
```swift
import Foundation

enum SkillArgumentParsing {
    static func decodeArguments<T: Decodable>(from json: String) throws -> T {
        guard let data = json.data(using: .utf8) else {
            throw SkillError.invalidArguments("Invalid JSON encoding")
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw SkillError.invalidArguments("Failed to parse arguments: \(error.localizedDescription)")
        }
    }
}
```

**Step 4: Run test to verify it passes**
Run: `Cmd+U`, confirm `SkillArgumentParsingTests` passes.

**Step 5: Commit**
```bash
git add HeyLlama/Services/Skills/Helpers/SkillArgumentParsing.swift HeyLlamaTests/SkillArgumentParsingTests.swift
git commit -m "feat(skills): add argument parsing helper"
```

---

### Task 2: Add location helpers and tests

**Files:**
- Create: `HeyLlama/Services/Skills/Helpers/LocationHelpers.swift`
- Modify: `HeyLlama/Services/Skills/WeatherForecastSkill.swift`
- Test: `HeyLlamaTests/LocationHelpersTests.swift`
- Update: `HeyLlamaTests/WeatherForecastSkillTests.swift`

**Step 1: Write the failing test**
```swift
import XCTest
@testable import HeyLlama

final class LocationHelpersTests: XCTestCase {
    func testNormalizeLocationTokenReturnsNilForUserTokens() {
        XCTAssertNil(LocationHelpers.normalizeLocationToken("user"))
        XCTAssertNil(LocationHelpers.normalizeLocationToken("Current Location"))
        XCTAssertNil(LocationHelpers.normalizeLocationToken(" here "))
    }

    func testNormalizeLocationTokenPreservesNamedLocation() {
        XCTAssertEqual(LocationHelpers.normalizeLocationToken("Paris"), "Paris")
    }
}
```

**Step 2: Run test to verify it fails**
Run: `Cmd+U`, confirm `LocationHelpersTests` fails because `LocationHelpers` is missing.

**Step 3: Write minimal implementation**
```swift
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
```

**Step 4: Update WeatherForecastSkill to use helpers**
Replace local helpers with:
- `LocationHelpers.normalizeLocationToken(...)`
- `LocationHelpers.geocodeLocation(...)`
- `LocationHelpers.getCurrentLocation()`

**Step 5: Update WeatherForecastSkillTests**
Replace normalization test to call `LocationHelpers.normalizeLocationToken(...)` directly.

**Step 6: Run tests to verify they pass**
Run: `Cmd+U` and confirm `LocationHelpersTests` and existing weather tests pass.

**Step 7: Commit**
```bash
git add HeyLlama/Services/Skills/Helpers/LocationHelpers.swift HeyLlama/Services/Skills/WeatherForecastSkill.swift HeyLlamaTests/LocationHelpersTests.swift HeyLlamaTests/WeatherForecastSkillTests.swift
git commit -m "refactor(skills): extract location helpers"
```

---

### Task 3: Add reminders helpers and tests

**Files:**
- Create: `HeyLlama/Services/Skills/Helpers/RemindersHelpers.swift`
- Modify: `HeyLlama/Services/Skills/RemindersAddItemSkill.swift`
- Test: `HeyLlamaTests/RemindersHelpersTests.swift`

**Step 1: Write the failing test**
```swift
import XCTest
@testable import HeyLlama

final class RemindersHelpersTests: XCTestCase {
    func testParseDueDateISO8601ReturnsNilForInvalid() {
        XCTAssertNil(RemindersHelpers.parseDueDateISO8601("not-a-date"))
    }
}
```

**Step 2: Run test to verify it fails**
Run: `Cmd+U`, confirm failure because `RemindersHelpers` is missing.

**Step 3: Write minimal implementation**
```swift
import EventKit
import Foundation

enum RemindersHelpers {
    static func findReminderList(named name: String, in eventStore: EKEventStore) throws -> EKCalendar {
        let calendars = eventStore.calendars(for: .reminder)
        if let target = calendars.first(where: {
            $0.title.localizedCaseInsensitiveCompare(name) == .orderedSame
        }) {
            return target
        }

        let availableLists = calendars.map { $0.title }.joined(separator: ", ")
        throw SkillError.executionFailed(
            "Could not find a Reminders list named '\(name)'. " +
            "Available lists: \(availableLists.isEmpty ? "none" : availableLists)"
        )
    }

    static func parseDueDateISO8601(_ dueDateString: String) -> DateComponents? {
        let formatter = ISO8601DateFormatter()
        guard let dueDate = formatter.date(from: dueDateString) else {
            return nil
        }
        return Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: dueDate)
    }
}
```

**Step 4: Update RemindersAddItemSkill to use helpers**
Replace inline list lookup and due-date parsing with:
- `RemindersHelpers.findReminderList(named:in:)`
- `RemindersHelpers.parseDueDateISO8601(_:)`

**Step 5: Run tests to verify they pass**
Run: `Cmd+U`, confirm `RemindersHelpersTests` passes.

**Step 6: Commit**
```bash
git add HeyLlama/Services/Skills/Helpers/RemindersHelpers.swift HeyLlama/Services/Skills/RemindersAddItemSkill.swift HeyLlamaTests/RemindersHelpersTests.swift
git commit -m "refactor(skills): extract reminders helpers"
```

---

### Task 4: Clean up and verify

**Files:**
- Modify: `HeyLlama/Services/Skills/WeatherForecastSkill.swift`
- Modify: `HeyLlama/Services/Skills/RemindersAddItemSkill.swift`

**Step 1: Remove unused imports and helpers**
Remove any now-unused helper functions or imports in the skill files.

**Step 2: Run full tests**
Run: `Cmd+U` and confirm all tests pass.

**Step 3: Commit**
```bash
git add HeyLlama/Services/Skills/WeatherForecastSkill.swift HeyLlama/Services/Skills/RemindersAddItemSkill.swift
git commit -m "chore(skills): tidy helpers integration"
```
