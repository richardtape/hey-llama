import XCTest
@testable import HeyLlama

final class AppleMusicNowPlayingSkillTests: XCTestCase {

    func testSkillHasCorrectId() {
        XCTAssertEqual(AppleMusicNowPlayingSkill.id, "music.now_playing")
    }

    func testSkillHasCorrectName() {
        XCTAssertEqual(AppleMusicNowPlayingSkill.name, "Now Playing")
    }

    func testSkillRequiresMusicPermission() {
        XCTAssertTrue(AppleMusicNowPlayingSkill.requiredPermissions.contains(.music))
    }

    func testArgumentsJSONSchemaIsValidJSON() {
        let data = AppleMusicNowPlayingSkill.argumentsJSONSchema.data(using: .utf8)!
        XCTAssertNoThrow(try JSONSerialization.jsonObject(with: data))
    }

    func testArgumentsMatchJSONSchema() throws {
        try SkillSchemaValidator.validate(
            structType: AppleMusicNowPlayingArguments.self,
            jsonSchema: AppleMusicNowPlayingSkill.argumentsJSONSchema
        )
    }

    func testCanDecodeArgumentsFromJSON() throws {
        let json = """
            {}
            """
        let data = json.data(using: .utf8)!
        XCTAssertNoThrow(try JSONDecoder().decode(AppleMusicNowPlayingArguments.self, from: data))
    }
}
