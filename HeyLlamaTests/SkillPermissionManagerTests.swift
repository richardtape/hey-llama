import XCTest
@testable import HeyLlama

final class SkillPermissionManagerTests: XCTestCase {

    func testCheckRemindersPermissionStatus() async {
        let manager = SkillPermissionManager()
        let status = await manager.checkPermissionStatus(.reminders)

        // Status should be one of the valid values
        XCTAssertTrue([.granted, .denied, .undetermined].contains(status))
    }

    func testCheckLocationPermissionStatus() async {
        let manager = SkillPermissionManager()
        let status = await manager.checkPermissionStatus(.location)

        // Status should be one of the valid values
        XCTAssertTrue([.granted, .denied, .undetermined].contains(status))
    }

    func testCheckAllPermissionsForSkillWithNoPermissions() async {
        let manager = SkillPermissionManager()
        // Weather skill requires location, reminders requires reminders
        // There's no skill with no permissions in our enum, so we test with an empty array
        let allGranted = await manager.checkAllPermissions(forPermissions: [])
        XCTAssertTrue(allGranted, "Empty permissions array should return true")
    }

    func testHasAllPermissionsForSkill() async {
        let manager = SkillPermissionManager()
        let skill = RegisteredSkill.remindersAddItem

        // Check current status - we can't know for sure what it is,
        // but we can verify the method works
        let hasAll = await manager.hasAllPermissions(for: skill)
        let status = await manager.checkPermissionStatus(.reminders)

        if status == .granted {
            XCTAssertTrue(hasAll)
        } else {
            XCTAssertFalse(hasAll)
        }
    }

    func testMissingPermissions() async {
        let manager = SkillPermissionManager()
        let skill = RegisteredSkill.weatherForecast

        let missing = await manager.missingPermissions(for: skill)

        // Location permission is likely not granted in test environment
        let status = await manager.checkPermissionStatus(.location)
        if status == .granted {
            XCTAssertTrue(missing.isEmpty)
        } else {
            XCTAssertTrue(missing.contains(.location))
        }
    }

    func testPermissionStatusEquatable() {
        let granted1 = Permissions.PermissionStatus.granted
        let granted2 = Permissions.PermissionStatus.granted
        let denied = Permissions.PermissionStatus.denied

        XCTAssertEqual(granted1, granted2)
        XCTAssertNotEqual(granted1, denied)
    }
}
