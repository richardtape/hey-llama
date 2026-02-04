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

    func testCheckMusicPermissionStatus() async {
        let manager = SkillPermissionManager()
        let status = await manager.checkPermissionStatus(.music)

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

    func testHasAllPermissionsForSkillType() async {
        let manager = SkillPermissionManager()
        let skillType = RemindersAddItemSkill.self

        // Check current status - we can't know for sure what it is,
        // but we can verify the method works
        let hasAll = await manager.hasAllPermissions(forSkillType: skillType)
        let status = await manager.checkPermissionStatus(.reminders)

        if status == .granted {
            XCTAssertTrue(hasAll)
        } else {
            XCTAssertFalse(hasAll)
        }
    }

    func testMissingPermissionsForSkillType() async {
        let manager = SkillPermissionManager()
        let skillType = WeatherForecastSkill.self

        let missing = await manager.missingPermissions(forSkillType: skillType)

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
