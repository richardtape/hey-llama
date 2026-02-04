import XCTest
@testable import HeyLlama

final class AppleMusicPlayShuffledSkillTests: XCTestCase {

    func testSkillHasCorrectId() {
        XCTAssertEqual(AppleMusicPlayShuffledSkill.id, "music.play_shuffled")
    }

    func testSkillHasCorrectName() {
        XCTAssertEqual(AppleMusicPlayShuffledSkill.name, "Play Shuffled")
    }

    func testSkillRequiresMusicPermission() {
        XCTAssertTrue(AppleMusicPlayShuffledSkill.requiredPermissions.contains(.music))
    }

    func testArgumentsJSONSchemaIsValidJSON() {
        let data = AppleMusicPlayShuffledSkill.argumentsJSONSchema.data(using: .utf8)!
        XCTAssertNoThrow(try JSONSerialization.jsonObject(with: data))
    }

    func testArgumentsMatchJSONSchema() throws {
        try SkillSchemaValidator.validate(
            structType: AppleMusicPlayShuffledArguments.self,
            jsonSchema: AppleMusicPlayShuffledSkill.argumentsJSONSchema
        )
    }

    func testCanDecodeArgumentsFromJSON() throws {
        let json = """
            {"query": "CCO Adventures", "entityType": "playlist", "source": "library"}
            """
        let data = json.data(using: .utf8)!
        let args = try JSONDecoder().decode(AppleMusicPlayShuffledArguments.self, from: data)

        XCTAssertEqual(args.query, "CCO Adventures")
        XCTAssertEqual(args.entityType, "playlist")
        XCTAssertEqual(args.source, "library")
    }
}
