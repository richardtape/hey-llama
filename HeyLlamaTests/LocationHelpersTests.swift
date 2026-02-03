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

    func testNormalizeLocationTokenFiltersSpeakerName() {
        // LLMs sometimes pass the speaker's name as a location when user says "my weather"
        // e.g., "What's my weather?" with speaker "Rich" -> location: "Rich"
        XCTAssertNil(LocationHelpers.normalizeLocationToken("Rich", speakerName: "Rich"))
        XCTAssertNil(LocationHelpers.normalizeLocationToken("RICH", speakerName: "Rich"))
        XCTAssertNil(LocationHelpers.normalizeLocationToken("rich", speakerName: "Rich"))

        // But should preserve actual place names even if they happen to match a name
        XCTAssertEqual(LocationHelpers.normalizeLocationToken("Paris", speakerName: "Rich"), "Paris")

        // Should work without speaker name (backward compatible)
        XCTAssertEqual(LocationHelpers.normalizeLocationToken("Rich"), "Rich")
    }
}
