import XCTest
@testable import HeyLlama

final class AppleMusicControlSkillTests: XCTestCase {

    func testSkillHasCorrectId() {
        XCTAssertEqual(AppleMusicControlSkill.id, "music.control")
    }

    func testSkillHasCorrectName() {
        XCTAssertEqual(AppleMusicControlSkill.name, "Music Controls")
    }

    func testSkillRequiresMusicPermission() {
        XCTAssertTrue(AppleMusicControlSkill.requiredPermissions.contains(.music))
    }

    func testArgumentsJSONSchemaIsValidJSON() {
        let data = AppleMusicControlSkill.argumentsJSONSchema.data(using: .utf8)!
        XCTAssertNoThrow(try JSONSerialization.jsonObject(with: data))
    }

    func testArgumentsMatchJSONSchema() throws {
        try SkillSchemaValidator.validate(
            structType: AppleMusicControlArguments.self,
            jsonSchema: AppleMusicControlSkill.argumentsJSONSchema
        )
    }

    func testCanDecodeArgumentsFromJSON() throws {
        let json = """
            {"action": "pause", "mode": "off"}
            """
        let data = json.data(using: .utf8)!
        let args = try JSONDecoder().decode(AppleMusicControlArguments.self, from: data)

        XCTAssertEqual(args.action, "pause")
        XCTAssertEqual(args.mode, "off")
    }
}
