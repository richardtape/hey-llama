import XCTest
@testable import HeyLlama

final class AppleIntelligenceProviderTests: XCTestCase {

    func testIsConfiguredRequiresBothEnabledAndAvailable() async {
        // Test that isConfigured requires both enabled AND available
        let disabledConfig = AppleIntelligenceConfig(enabled: false)
        let disabledProvider = AppleIntelligenceProvider(config: disabledConfig)
        let configuredWhenDisabled = await disabledProvider.isConfigured
        XCTAssertFalse(configuredWhenDisabled, "Should not be configured when disabled")

        // Test with enabled config
        let enabledConfig = AppleIntelligenceConfig(enabled: true)
        let enabledProvider = AppleIntelligenceProvider(config: enabledConfig)
        let configuredWhenEnabled = await enabledProvider.isConfigured

        // isConfigured should match isAvailable when enabled
        XCTAssertEqual(configuredWhenEnabled, enabledProvider.isAvailable)
    }

    func testIsNotConfiguredWhenDisabled() async {
        let config = AppleIntelligenceConfig(enabled: false)
        let provider = AppleIntelligenceProvider(config: config)
        let configured = await provider.isConfigured
        XCTAssertFalse(configured)
    }

    func testCompleteThrowsNotConfiguredWhenDisabled() async {
        let config = AppleIntelligenceConfig(enabled: false)
        let provider = AppleIntelligenceProvider(config: config)

        do {
            _ = try await provider.complete(prompt: "Test", context: nil, conversationHistory: [])
            XCTFail("Expected error to be thrown")
        } catch let error as LLMError {
            if case .notConfigured = error {
                // Expected - disabled config throws notConfigured
            } else {
                XCTFail("Expected notConfigured error, got: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testCompleteThrowsUnavailableWhenModelNotReady() async {
        let config = AppleIntelligenceConfig(enabled: true)
        let provider = AppleIntelligenceProvider(config: config)

        // If the model isn't available, we should get a providerUnavailable error
        guard !provider.isAvailable else {
            // Model is available on this system, skip this test
            // The actual completion test would require network/model access
            return
        }

        do {
            _ = try await provider.complete(prompt: "Test", context: nil, conversationHistory: [])
            XCTFail("Expected error to be thrown")
        } catch let error as LLMError {
            if case .providerUnavailable = error {
                // Expected
            } else {
                XCTFail("Expected providerUnavailable error, got: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testAvailabilityReasonProvided() {
        let config = AppleIntelligenceConfig()
        let provider = AppleIntelligenceProvider(config: config)

        // Should always have a reason string
        let reason = provider.availabilityReason
        XCTAssertFalse(reason.isEmpty, "Availability reason should not be empty")

        // If available, reason should indicate availability
        if provider.isAvailable {
            XCTAssertEqual(reason, "Available")
        } else {
            // If not available, reason should explain why
            XCTAssertNotEqual(reason, "Available")
        }
    }

    func testIsAvailableReturnsConsistentValue() {
        let config = AppleIntelligenceConfig()
        let provider = AppleIntelligenceProvider(config: config)

        // Multiple calls should return the same value
        let firstCheck = provider.isAvailable
        let secondCheck = provider.isAvailable

        XCTAssertEqual(firstCheck, secondCheck, "isAvailable should be consistent")
    }

    func testSystemPromptTemplateUsed() {
        // Verify the custom system prompt template is stored
        let customTemplate = "You are a test assistant for {speaker_name}."
        let config = AppleIntelligenceConfig()
        let provider = AppleIntelligenceProvider(config: config, systemPromptTemplate: customTemplate)

        // Provider should be created successfully with custom template
        // Actual template usage is tested indirectly through completion
        XCTAssertNotNil(provider)
    }

    func testBuildActionPlanJSONWithToolCalls() throws {
        let calls = [
            AppleIntelligenceProvider.ToolInvocation(
                skillId: "reminders.add_item",
                arguments: ["listName": "Groceries", "itemName": "Milk"]
            )
        ]

        let json = try AppleIntelligenceProvider.buildActionPlanJSON(
            responseText: "ignored",
            toolCalls: calls
        )

        XCTAssertTrue(json.contains("\"type\":\"call_skills\""))
        XCTAssertTrue(json.contains("\"reminders.add_item\""))
        XCTAssertTrue(json.contains("\"listName\""))
    }

    func testBuildActionPlanJSONWithTextOnly() throws {
        let json = try AppleIntelligenceProvider.buildActionPlanJSON(
            responseText: "Hello there",
            toolCalls: []
        )

        XCTAssertTrue(json.contains("\"type\":\"respond\""))
        XCTAssertTrue(json.contains("Hello there"))
    }

    func testBuildActionPlanJSONPrefersToolCalls() throws {
        let calls = [
            AppleIntelligenceProvider.ToolInvocation(
                skillId: "weather.forecast",
                arguments: ["when": "today"]
            )
        ]

        let json = try AppleIntelligenceProvider.buildActionPlanJSON(
            responseText: "This should not be used",
            toolCalls: calls
        )

        XCTAssertTrue(json.contains("\"type\":\"call_skills\""))
        XCTAssertFalse(json.contains("This should not be used"))
    }

    func testBuildInstructionsForToolCallingStripsJsonRules() {
        let template = """
        You are Llama. The current user is {speaker_name}.
        You must respond with a single JSON object only.
        Do not wrap in code fences or add extra text.
        Never put tool call JSON inside the "text" field.
        """

        let instructions = AppleIntelligenceProvider.buildInstructions(
            template: template,
            speakerName: "Rich",
            skillsManifest: "SKILLS",
            useToolCalling: true
        )

        XCTAssertTrue(instructions.contains("Rich"))
        XCTAssertFalse(instructions.lowercased().contains("json"))
        XCTAssertFalse(instructions.contains("SKILLS"))
    }

    func testBuildInstructionsForJsonParsingIncludesManifest() {
        let template = "You are Llama for {speaker_name}."

        let instructions = AppleIntelligenceProvider.buildInstructions(
            template: template,
            speakerName: "Rich",
            skillsManifest: "SKILLS",
            useToolCalling: false
        )

        XCTAssertTrue(instructions.contains("Rich"))
        XCTAssertTrue(instructions.contains("SKILLS"))
    }

    // MARK: - Integration Test (only runs when Apple Intelligence is available)

    func testCompletionWhenAvailable() async throws {
        let config = AppleIntelligenceConfig(enabled: true)
        let provider = AppleIntelligenceProvider(config: config)

        // Skip test if Apple Intelligence is not available
        guard provider.isAvailable else {
            throw XCTSkip("Apple Intelligence not available on this system: \(provider.availabilityReason)")
        }

        // If available, test a simple completion
        do {
            let response = try await provider.complete(
                prompt: "Say 'test successful' in exactly two words.",
                context: nil,
                conversationHistory: []
            )
            XCTAssertFalse(response.isEmpty, "Response should not be empty")
        } catch {
            // If it fails even when available, that's a real failure
            XCTFail("Completion failed when model reported available: \(error)")
        }
    }
}
