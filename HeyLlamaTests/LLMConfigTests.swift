import XCTest
@testable import HeyLlama

final class LLMConfigTests: XCTestCase {

    func testLLMProviderCases() {
        XCTAssertEqual(LLMProvider.appleIntelligence.rawValue, "appleIntelligence")
        XCTAssertEqual(LLMProvider.openAICompatible.rawValue, "openAICompatible")
    }

    func testLLMProviderCodable() throws {
        let provider = LLMProvider.openAICompatible
        let data = try JSONEncoder().encode(provider)
        let decoded = try JSONDecoder().decode(LLMProvider.self, from: data)
        XCTAssertEqual(decoded, provider)
    }

    func testAppleIntelligenceConfigDefaults() {
        let config = AppleIntelligenceConfig()
        XCTAssertTrue(config.enabled)
        XCTAssertNil(config.preferredModel)
    }

    func testOpenAICompatibleConfigDefaults() {
        let config = OpenAICompatibleConfig()
        XCTAssertTrue(config.enabled)
        XCTAssertEqual(config.baseURL, "http://localhost:11434/v1")
        XCTAssertNil(config.apiKey)
        XCTAssertEqual(config.model, "")
        XCTAssertEqual(config.timeoutSeconds, 60)
    }

    func testOpenAICompatibleConfigIsConfigured() {
        var config = OpenAICompatibleConfig()

        // Empty model = not configured
        XCTAssertFalse(config.isConfigured)

        // With model = configured
        config.model = "llama3.2"
        XCTAssertTrue(config.isConfigured)

        // Empty baseURL = not configured
        config.baseURL = ""
        XCTAssertFalse(config.isConfigured)
    }

    func testLLMConfigDefaults() {
        let config = LLMConfig.default
        XCTAssertEqual(config.provider, .appleIntelligence)
        XCTAssertTrue(config.systemPrompt.contains("Llama"))
        XCTAssertEqual(config.conversationTimeoutMinutes, 5)
        XCTAssertEqual(config.maxConversationTurns, 10)
    }

    func testLLMConfigSystemPromptContainsSpeakerPlaceholder() {
        let config = LLMConfig.default
        XCTAssertTrue(config.systemPrompt.contains("{speaker_name}"))
    }

    func testLLMConfigCodable() throws {
        var config = LLMConfig.default
        config.provider = .openAICompatible
        config.openAICompatible.model = "gpt-4"
        config.openAICompatible.apiKey = "test-key"

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(config)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(LLMConfig.self, from: data)

        XCTAssertEqual(decoded.provider, .openAICompatible)
        XCTAssertEqual(decoded.openAICompatible.model, "gpt-4")
        XCTAssertEqual(decoded.openAICompatible.apiKey, "test-key")
    }
}
