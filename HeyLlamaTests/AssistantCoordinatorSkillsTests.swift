import XCTest
@testable import HeyLlama

@MainActor
final class AssistantCoordinatorSkillsTests: XCTestCase {

    func testCoordinatorHasSkillsRegistry() async {
        let coordinator = AssistantCoordinator()
        XCTAssertNotNil(coordinator.skillsRegistry)
    }

    func testSkillsRegistryHasBuiltInSkills() async {
        let coordinator = AssistantCoordinator()
        let skills = coordinator.skillsRegistry.allSkills
        XCTAssertEqual(skills.count, 2)
    }

    func testProcessActionPlanRespond() async throws {
        let mockLLM = MockLLMService()
        await mockLLM.setMockResponse("""
        {"type":"respond","text":"Hello! How can I help?"}
        """)

        let coordinator = AssistantCoordinator(llmService: mockLLM)

        // Process a respond action plan
        let result = try await coordinator.processActionPlan(
            from: """
            {"type":"respond","text":"Hello! How can I help?"}
            """
        )

        XCTAssertEqual(result, "Hello! How can I help?")
    }

    func testProcessActionPlanPlainText() async throws {
        let coordinator = AssistantCoordinator()

        // When LLM returns plain text (not JSON), it should pass through
        let result = try await coordinator.processActionPlan(
            from: "This is just plain text, not JSON"
        )

        XCTAssertEqual(result, "This is just plain text, not JSON")
    }

    func testProcessActionPlanCallSkillDisabled() async throws {
        let coordinator = AssistantCoordinator()
        coordinator.updateSkillsConfig(SkillsConfig())

        // Try to call a disabled skill
        let result = try await coordinator.processActionPlan(
            from: """
            {"type":"call_skills","calls":[{"skillId":"weather.forecast","arguments":{"when":"today"}}]}
            """
        )

        // Should return a message about the skill being disabled
        XCTAssertTrue(result.contains("disabled"))
    }

    func testProcessActionPlanCallNonexistentSkill() async throws {
        let coordinator = AssistantCoordinator()

        let result = try await coordinator.processActionPlan(
            from: """
            {"type":"call_skills","calls":[{"skillId":"nonexistent.skill","arguments":{}}]}
            """
        )

        XCTAssertTrue(result.contains("couldn't find"))
    }

    func testSkillsManifestGeneratedForEnabledSkills() async {
        var config = AssistantConfig.default
        config.skills.enabledSkillIds = ["weather.forecast"]

        let coordinator = AssistantCoordinator()
        coordinator.updateSkillsConfig(config.skills)

        let manifest = coordinator.skillsRegistry.generateSkillsManifest()
        XCTAssertTrue(manifest.contains("weather.forecast"))
        XCTAssertFalse(manifest.contains("reminders.add_item"))
    }

    func testUpdateSkillsConfig() async {
        let coordinator = AssistantCoordinator()

        // Ensure known baseline
        coordinator.updateSkillsConfig(SkillsConfig())
        XCTAssertTrue(coordinator.skillsRegistry.enabledSkills.isEmpty)

        // Enable a skill
        var newConfig = SkillsConfig()
        newConfig.enabledSkillIds = ["weather.forecast"]
        coordinator.updateSkillsConfig(newConfig)

        XCTAssertEqual(coordinator.skillsRegistry.enabledSkills.count, 1)
        XCTAssertTrue(coordinator.skillsRegistry.isSkillEnabled("weather.forecast"))
    }

    func testMockLLMReceivesSkillsManifest() async throws {
        let mockLLM = MockLLMService()
        await mockLLM.setMockResponse("test response")

        var config = AssistantConfig.default
        config.skills.enabledSkillIds = ["weather.forecast"]

        let coordinator = AssistantCoordinator(llmService: mockLLM)
        coordinator.updateSkillsConfig(config.skills)

        // The manifest would be passed during processCommand, but we can test
        // that the coordinator has the registry properly configured
        let manifest = coordinator.skillsRegistry.generateSkillsManifest()
        XCTAssertTrue(manifest.contains("weather.forecast"))
        XCTAssertTrue(manifest.contains("call_skills"))
    }

    func testCompleteAndProcessActionPlanRetriesOnInvalidJSON() async throws {
        let mockLLM = MockLLMService()
        await mockLLM.setMockResponses([
            "Added 'oat milk' to your Groceries list.",
            "{\"type\":\"respond\",\"text\":\"ok\"}"
        ])

        let coordinator = AssistantCoordinator(llmService: mockLLM)

        let result = try await coordinator.completeAndProcessActionPlan(
            prompt: "add oat milk to the groceries list",
            context: nil,
            conversationHistory: [],
            skillsManifest: "skills manifest"
        )

        XCTAssertEqual(result, "ok")

        let count = await mockLLM.completionCount
        XCTAssertEqual(count, 2)
    }
}
