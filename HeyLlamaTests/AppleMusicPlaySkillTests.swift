import XCTest
@testable import HeyLlama

final class AppleMusicPlaySkillTests: XCTestCase {

    func testSkillHasCorrectId() {
        XCTAssertEqual(AppleMusicPlaySkill.id, "music.play")
    }

    func testSkillHasCorrectName() {
        XCTAssertEqual(AppleMusicPlaySkill.name, "Play Music")
    }

    func testSkillRequiresMusicPermission() {
        XCTAssertTrue(AppleMusicPlaySkill.requiredPermissions.contains(.music))
    }

    func testArgumentsJSONSchemaIsValidJSON() {
        let data = AppleMusicPlaySkill.argumentsJSONSchema.data(using: .utf8)!
        XCTAssertNoThrow(try JSONSerialization.jsonObject(with: data))
    }

    func testArgumentsMatchJSONSchema() throws {
        try SkillSchemaValidator.validate(
            structType: AppleMusicPlayArguments.self,
            jsonSchema: AppleMusicPlaySkill.argumentsJSONSchema
        )
    }

    func testCanDecodeArgumentsFromJSON() throws {
        let json = """
            {"query": "Halo", "entityType": "song", "source": "library"}
            """
        let data = json.data(using: .utf8)!
        let args = try JSONDecoder().decode(AppleMusicPlayArguments.self, from: data)

        XCTAssertEqual(args.query, "Halo")
        XCTAssertEqual(args.entityType, "song")
        XCTAssertEqual(args.source, "library")
    }
}
