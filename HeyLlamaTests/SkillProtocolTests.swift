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

    // Test that Skill types have the required properties
    func testSkillTypeHasRequiredProperties() {
        let skillType = WeatherForecastSkill.self

        XCTAssertEqual(skillType.id, "weather.forecast")
        XCTAssertEqual(skillType.name, "Weather Forecast")
        XCTAssertFalse(skillType.skillDescription.isEmpty)
        XCTAssertEqual(skillType.requiredPermissions, [.location])
        XCTAssertFalse(skillType.argumentsJSONSchema.isEmpty)
    }
}

// MARK: - Skill Protocol Conformance Tests

final class SkillProtocolConformanceTests: XCTestCase {

    struct MockSkill: Skill {
        static let id = "test.mock"
        static let name = "Mock Skill"
        static let skillDescription = "A mock skill for testing"
        static let requiredPermissions: [SkillPermission] = []
        static let includesInResponseAgent = true
        static let argumentsJSONSchema = """
            {"type": "object", "properties": {"input": {"type": "string"}}, "required": ["input"]}
            """

        struct Arguments: Codable {
            let input: String
        }

        func execute(arguments: Arguments, context: SkillContext) async throws -> SkillResult {
            return SkillResult(text: "Received: \(arguments.input)")
        }
    }

    func testMockSkillConformsToProtocol() {
        XCTAssertEqual(MockSkill.id, "test.mock")
        XCTAssertEqual(MockSkill.name, "Mock Skill")
        XCTAssertEqual(MockSkill.skillDescription, "A mock skill for testing")
        XCTAssertEqual(MockSkill.requiredPermissions, [])
        XCTAssertTrue(MockSkill.includesInResponseAgent)
        XCTAssertFalse(MockSkill.argumentsJSONSchema.isEmpty)
    }

    func testMockSkillCanExecute() async throws {
        let skill = MockSkill()
        let args = MockSkill.Arguments(input: "hello")
        let context = SkillContext()

        let result = try await skill.execute(arguments: args, context: context)

        XCTAssertEqual(result.text, "Received: hello")
    }
}
