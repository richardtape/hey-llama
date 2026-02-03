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
