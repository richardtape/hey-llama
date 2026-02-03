import XCTest
@testable import HeyLlama

final class RemindersAddItemSkillTests: XCTestCase {

    func testSkillHasCorrectId() {
        let skill = RegisteredSkill.remindersAddItem
        XCTAssertEqual(skill.id, "reminders.add_item")
    }

    func testSkillRequiresRemindersPermission() {
        let skill = RegisteredSkill.remindersAddItem
        XCTAssertTrue(skill.requiredPermissions.contains(.reminders))
    }

    func testArgumentSchemaIsValidJSON() {
        let skill = RegisteredSkill.remindersAddItem
        let schemaData = skill.argumentSchemaJSON.data(using: .utf8)!

        XCTAssertNoThrow(try JSONSerialization.jsonObject(with: schemaData))
    }

    func testParseRemindersArguments() throws {
        let args = try RemindersAddItemSkill.parseArguments(from: """
        {"listName": "Groceries", "itemName": "Milk"}
        """)

        XCTAssertEqual(args.listName, "Groceries")
        XCTAssertEqual(args.itemName, "Milk")
        XCTAssertNil(args.notes)
        XCTAssertNil(args.dueDateISO8601)
    }

    func testParseRemindersArgumentsWithOptionalFields() throws {
        let args = try RemindersAddItemSkill.parseArguments(from: """
        {
            "listName": "Shopping",
            "itemName": "Bread",
            "notes": "Whole wheat",
            "dueDateISO8601": "2026-02-03T10:00:00Z"
        }
        """)

        XCTAssertEqual(args.listName, "Shopping")
        XCTAssertEqual(args.itemName, "Bread")
        XCTAssertEqual(args.notes, "Whole wheat")
        XCTAssertEqual(args.dueDateISO8601, "2026-02-03T10:00:00Z")
    }

    func testParseRemindersArgumentsMissingListName() {
        XCTAssertThrowsError(try RemindersAddItemSkill.parseArguments(from: """
        {"itemName": "Milk"}
        """)) { error in
            guard case SkillError.invalidArguments = error else {
                XCTFail("Expected invalidArguments error, got \(error)")
                return
            }
        }
    }

    func testParseRemindersArgumentsMissingItemName() {
        XCTAssertThrowsError(try RemindersAddItemSkill.parseArguments(from: """
        {"listName": "Groceries"}
        """)) { error in
            guard case SkillError.invalidArguments = error else {
                XCTFail("Expected invalidArguments error, got \(error)")
                return
            }
        }
    }

    func testParseRemindersArgumentsInvalidJSON() {
        XCTAssertThrowsError(try RemindersAddItemSkill.parseArguments(from: "not json")) { error in
            guard case SkillError.invalidArguments = error else {
                XCTFail("Expected invalidArguments error, got \(error)")
                return
            }
        }
    }

    func testParseDueDateFromISO8601() {
        let dateString = "2026-02-03T10:00:00Z"
        let formatter = ISO8601DateFormatter()
        let date = formatter.date(from: dateString)

        XCTAssertNotNil(date)

        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date!)

        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 2)
        XCTAssertEqual(components.day, 3)
    }
}
