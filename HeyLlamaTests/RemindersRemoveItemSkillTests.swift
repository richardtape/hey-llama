import XCTest
@testable import HeyLlama

final class RemindersRemoveItemSkillTests: XCTestCase {

    // MARK: - Metadata Tests

    func testSkillHasCorrectId() {
        XCTAssertEqual(RemindersRemoveItemSkill.id, "reminders.remove_item")
    }

    func testSkillHasCorrectName() {
        XCTAssertEqual(RemindersRemoveItemSkill.name, "Remove Reminder")
    }

    func testSkillRequiresRemindersPermission() {
        XCTAssertTrue(RemindersRemoveItemSkill.requiredPermissions.contains(.reminders))
    }

    func testSkillIncludesInResponseAgent() {
        XCTAssertTrue(RemindersRemoveItemSkill.includesInResponseAgent)
    }

    // MARK: - Schema Validation Tests

    func testArgumentsJSONSchemaIsValidJSON() {
        let data = RemindersRemoveItemSkill.argumentsJSONSchema.data(using: .utf8)!
        XCTAssertNoThrow(try JSONSerialization.jsonObject(with: data))
    }

    func testArgumentsMatchJSONSchema() throws {
        try SkillSchemaValidator.validate(
            structType: RemindersRemoveItemArguments.self,
            jsonSchema: RemindersRemoveItemSkill.argumentsJSONSchema
        )
    }

    // MARK: - Argument Decoding Tests

    func testCanDecodeArgumentsFromJSON() throws {
        let json = """
            {"listName": "Groceries", "itemName": "Milk"}
            """
        let data = json.data(using: .utf8)!
        let args = try JSONDecoder().decode(RemindersRemoveItemArguments.self, from: data)

        XCTAssertEqual(args.listName, "Groceries")
        XCTAssertEqual(args.itemName, "Milk")
    }
}
