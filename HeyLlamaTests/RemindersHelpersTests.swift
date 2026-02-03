import XCTest
@testable import HeyLlama

final class RemindersHelpersTests: XCTestCase {
    func testParseDueDateISO8601ReturnsNilForInvalid() {
        XCTAssertNil(RemindersHelpers.parseDueDateISO8601("not-a-date"))
    }
}
