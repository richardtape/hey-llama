import XCTest
@testable import HeyLlama

final class AppleMusicAddToPlaylistSkillTests: XCTestCase {

    func testSkillHasCorrectId() {
        XCTAssertEqual(AppleMusicAddToPlaylistSkill.id, "music.add_to_playlist")
    }

    func testSkillHasCorrectName() {
        XCTAssertEqual(AppleMusicAddToPlaylistSkill.name, "Add Track to Playlist")
    }

    func testSkillRequiresMusicPermission() {
        XCTAssertTrue(AppleMusicAddToPlaylistSkill.requiredPermissions.contains(.music))
    }

    func testArgumentsJSONSchemaIsValidJSON() {
        let data = AppleMusicAddToPlaylistSkill.argumentsJSONSchema.data(using: .utf8)!
        XCTAssertNoThrow(try JSONSerialization.jsonObject(with: data))
    }

    func testArgumentsMatchJSONSchema() throws {
        try SkillSchemaValidator.validate(
            structType: AppleMusicAddToPlaylistArguments.self,
            jsonSchema: AppleMusicAddToPlaylistSkill.argumentsJSONSchema
        )
    }

    func testCanDecodeArgumentsFromJSON() throws {
        let json = """
            {"trackQuery": "Levitating", "playlistName": "Favorites", "source": "auto"}
            """
        let data = json.data(using: .utf8)!
        let args = try JSONDecoder().decode(AppleMusicAddToPlaylistArguments.self, from: data)

        XCTAssertEqual(args.trackQuery, "Levitating")
        XCTAssertEqual(args.playlistName, "Favorites")
        XCTAssertEqual(args.source, "auto")
    }
}
