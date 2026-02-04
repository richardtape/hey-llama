import XCTest
@testable import HeyLlama

final class RemindersCompleteItemSkillTests: XCTestCase {

    // MARK: - Metadata Tests

    func testSkillHasCorrectId() {
        XCTAssertEqual(RemindersCompleteItemSkill.id, "reminders.complete_item")
    }

    func testSkillHasCorrectName() {
        XCTAssertEqual(RemindersCompleteItemSkill.name, "Complete Reminder")
    }

    func testSkillRequiresRemindersPermission() {
        XCTAssertTrue(RemindersCompleteItemSkill.requiredPermissions.contains(.reminders))
    }

    func testSkillIncludesInResponseAgent() {
        XCTAssertTrue(RemindersCompleteItemSkill.includesInResponseAgent)
    }

    // MARK: - Schema Validation Tests

    func testArgumentsJSONSchemaIsValidJSON() {
        let data = RemindersCompleteItemSkill.argumentsJSONSchema.data(using: .utf8)!
        XCTAssertNoThrow(try JSONSerialization.jsonObject(with: data))
    }

    func testArgumentsMatchJSONSchema() throws {
        try SkillSchemaValidator.validate(
            structType: RemindersCompleteItemArguments.self,
            jsonSchema: RemindersCompleteItemSkill.argumentsJSONSchema
        )
    }

    // MARK: - Argument Decoding Tests

    func testCanDecodeArgumentsFromJSON() throws {
        let json = """
            {"listName": "Groceries", "itemName": "Milk"}
            """
        let data = json.data(using: .utf8)!
        let args = try JSONDecoder().decode(RemindersCompleteItemArguments.self, from: data)

        XCTAssertEqual(args.listName, "Groceries")
        XCTAssertEqual(args.itemName, "Milk")
    }
}
