import XCTest
import CoreLocation
@testable import HeyLlama

@MainActor
final class PermissionsTests: XCTestCase {
    override func tearDown() {
        LocationPermissionRequester.authorizationStatusProvider =
            LocationPermissionRequester.defaultAuthorizationStatusProvider
        super.tearDown()
    }

    func testCheckLocationStatusGranted() {
        LocationPermissionRequester.authorizationStatusProvider = { .authorizedAlways }
        let status = Permissions.checkLocationStatus()
        XCTAssertEqual(status, .granted)
    }

    func testCheckLocationStatusDenied() {
        LocationPermissionRequester.authorizationStatusProvider = { .denied }
        let status = Permissions.checkLocationStatus()
        XCTAssertEqual(status, .denied)
    }

    func testCheckLocationStatusUndetermined() {
        LocationPermissionRequester.authorizationStatusProvider = { .notDetermined }
        let status = Permissions.checkLocationStatus()
        XCTAssertEqual(status, .undetermined)
    }
}
