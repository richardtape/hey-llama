import XCTest
@testable import HeyLlama

final class RemindersReadItemsSkillTests: XCTestCase {

    // MARK: - Metadata Tests

    func testSkillHasCorrectId() {
        XCTAssertEqual(RemindersReadItemsSkill.id, "reminders.read_items")
    }

    func testSkillHasCorrectName() {
        XCTAssertEqual(RemindersReadItemsSkill.name, "Read Reminders")
    }

    func testSkillRequiresRemindersPermission() {
        XCTAssertTrue(RemindersReadItemsSkill.requiredPermissions.contains(.reminders))
    }

    func testSkillIncludesInResponseAgent() {
        XCTAssertTrue(RemindersReadItemsSkill.includesInResponseAgent)
    }

    // MARK: - Schema Validation Tests

    func testArgumentsJSONSchemaIsValidJSON() {
        let data = RemindersReadItemsSkill.argumentsJSONSchema.data(using: .utf8)!
        XCTAssertNoThrow(try JSONSerialization.jsonObject(with: data))
    }

    func testArgumentsMatchJSONSchema() throws {
        try SkillSchemaValidator.validate(
            structType: RemindersReadItemsArguments.self,
            jsonSchema: RemindersReadItemsSkill.argumentsJSONSchema
        )
    }

    // MARK: - Argument Decoding Tests

    func testCanDecodeArgumentsFromJSON() throws {
        let json = """
            {"listName": "Groceries"}
            """
        let data = json.data(using: .utf8)!
        let args = try JSONDecoder().decode(RemindersReadItemsArguments.self, from: data)

        XCTAssertEqual(args.listName, "Groceries")
        XCTAssertNil(args.status)
    }

    func testCanDecodeArgumentsWithStatus() throws {
        let json = """
            {"listName": "Groceries", "status": "completed"}
            """
        let data = json.data(using: .utf8)!
        let args = try JSONDecoder().decode(RemindersReadItemsArguments.self, from: data)

        XCTAssertEqual(args.listName, "Groceries")
        XCTAssertEqual(args.status, "completed")
    }
}
