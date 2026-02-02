import XCTest
@testable import HeyLlama

final class SkillProtocolTests: XCTestCase {

    func testSkillResultContainsText() {
        let result = SkillResult(text: "Operation completed", data: nil)

        XCTAssertEqual(result.text, "Operation completed")
        XCTAssertNil(result.data)
    }

    func testSkillResultWithData() {
        let data: [String: Any] = ["temperature": 72, "unit": "F"]
        let result = SkillResult(text: "Current temperature", data: data)

        XCTAssertEqual(result.text, "Current temperature")
        XCTAssertNotNil(result.data)
        XCTAssertEqual(result.data?["temperature"] as? Int, 72)
    }

    func testSkillPermissionHasDisplayName() {
        XCTAssertEqual(SkillPermission.reminders.displayName, "Reminders")
        XCTAssertEqual(SkillPermission.location.displayName, "Location")
    }

    func testSkillPermissionHasDescription() {
        XCTAssertFalse(SkillPermission.reminders.description.isEmpty)
        XCTAssertFalse(SkillPermission.location.description.isEmpty)
    }

    func testSkillContextDefaults() {
        let context = SkillContext()

        XCTAssertNil(context.speaker)
        XCTAssertEqual(context.source, .localMic)
        XCTAssertNotNil(context.timestamp)
    }

    func testSkillContextWithSpeaker() {
        let embedding = SpeakerEmbedding(vector: [Float](repeating: 0.1, count: 256), modelVersion: "test")
        let speaker = Speaker(name: "Test User", embedding: embedding)
        let context = SkillContext(speaker: speaker, source: .localMic)

        XCTAssertEqual(context.speaker?.name, "Test User")
    }

    func testSkillErrorDescriptions() {
        let deniedError = SkillError.permissionDenied(.reminders)
        XCTAssertTrue(deniedError.localizedDescription.contains("Reminders"))

        let notFoundError = SkillError.skillNotFound("test.skill")
        XCTAssertTrue(notFoundError.localizedDescription.contains("test.skill"))

        let disabledError = SkillError.skillDisabled("test.skill")
        XCTAssertTrue(disabledError.localizedDescription.contains("disabled"))
    }

    // Test the RegisteredSkill enum properties instead of protocol
    func testRegisteredSkillHasRequiredProperties() {
        let skill = RegisteredSkill.weatherForecast

        XCTAssertEqual(skill.id, "weather.forecast")
        XCTAssertEqual(skill.name, "Weather Forecast")
        XCTAssertFalse(skill.skillDescription.isEmpty)
        XCTAssertEqual(skill.requiredPermissions, [.location])
        XCTAssertFalse(skill.argumentSchemaJSON.isEmpty)
    }
}
