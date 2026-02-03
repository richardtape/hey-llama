import XCTest
@testable import HeyLlama

final class RemindersAddItemSkillTests: XCTestCase {

    // MARK: - Metadata Tests

    func testSkillHasCorrectId() {
        XCTAssertEqual(RemindersAddItemSkill.id, "reminders.add_item")
    }

    func testSkillHasCorrectName() {
        XCTAssertEqual(RemindersAddItemSkill.name, "Add Reminder")
    }

    func testSkillRequiresRemindersPermission() {
        XCTAssertTrue(RemindersAddItemSkill.requiredPermissions.contains(.reminders))
    }

    func testSkillIncludesInResponseAgent() {
        XCTAssertTrue(RemindersAddItemSkill.includesInResponseAgent)
    }

    // MARK: - Schema Validation Tests

    func testArgumentsJSONSchemaIsValidJSON() {
        let data = RemindersAddItemSkill.argumentsJSONSchema.data(using: .utf8)!
        XCTAssertNoThrow(try JSONSerialization.jsonObject(with: data))
    }

    func testArgumentsMatchJSONSchema() throws {
        try SkillSchemaValidator.validate(
            structType: RemindersAddItemArguments.self,
            jsonSchema: RemindersAddItemSkill.argumentsJSONSchema
        )
    }

    // MARK: - Argument Decoding Tests

    func testCanDecodeArgumentsFromJSON() throws {
        let json = """
            {"listName": "Groceries", "itemName": "Milk"}
            """
        let data = json.data(using: .utf8)!
        let args = try JSONDecoder().decode(RemindersAddItemArguments.self, from: data)

        XCTAssertEqual(args.listName, "Groceries")
        XCTAssertEqual(args.itemName, "Milk")
        XCTAssertNil(args.notes)
        XCTAssertNil(args.dueDateISO8601)
    }

    func testCanDecodeArgumentsWithOptionalFields() throws {
        let json = """
            {
                "listName": "Shopping",
                "itemName": "Bread",
                "notes": "Whole wheat",
                "dueDateISO8601": "2026-02-03T10:00:00Z"
            }
            """
        let data = json.data(using: .utf8)!
        let args = try JSONDecoder().decode(RemindersAddItemArguments.self, from: data)

        XCTAssertEqual(args.listName, "Shopping")
        XCTAssertEqual(args.itemName, "Bread")
        XCTAssertEqual(args.notes, "Whole wheat")
        XCTAssertEqual(args.dueDateISO8601, "2026-02-03T10:00:00Z")
    }

    // MARK: - Helper Tests

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
