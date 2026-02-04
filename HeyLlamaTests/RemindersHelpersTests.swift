import XCTest
@testable import HeyLlama

final class RemindersHelpersTests: XCTestCase {
    func testParseDueDateISO8601ReturnsNilForInvalid() {
        XCTAssertNil(RemindersHelpers.parseDueDateISO8601("not-a-date"))
    }

    func testBestFuzzyMatchNameReturnsClosest() {
        let options = ["Groceries", "Work", "Personal"]
        let match = RemindersHelpers.bestFuzzyMatchName(for: "grocery", in: options)
        XCTAssertEqual(match, "Groceries")
    }

    func testNormalizeStringRemovesPunctuationAndCollapsesSpaces() {
        let normalized = RemindersHelpers.normalizeString("  Groceries!!  List  ")
        XCTAssertEqual(normalized, "groceries list")
    }
}
