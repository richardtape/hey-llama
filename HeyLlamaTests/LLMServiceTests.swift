import XCTest
@testable import HeyLlama

final class LLMServiceTests: XCTestCase {

    func testIsConfiguredWithOpenAIProvider() async {
        var config = LLMConfig.default
        config.provider = .openAICompatible
        config.openAICompatible.model = "llama3.2"
        config.openAICompatible.baseURL = "http://localhost:11434/v1"

        let service = LLMService(config: config)
        let configured = await service.isConfigured
        XCTAssertTrue(configured)
    }

    func testIsNotConfiguredWithEmptyOpenAI() async {
        var config = LLMConfig.default
        config.provider = .openAICompatible
        config.openAICompatible.model = ""

        let service = LLMService(config: config)
        let configured = await service.isConfigured
        XCTAssertFalse(configured)
    }

    func testIsNotConfiguredWithAppleIntelligence() async {
        // Apple Intelligence is currently unavailable
        var config = LLMConfig.default
        config.provider = .appleIntelligence

        let service = LLMService(config: config)
        let configured = await service.isConfigured
        XCTAssertFalse(configured)
    }

    func testSelectedProviderReturnsCorrectType() {
        var config = LLMConfig.default
        config.provider = .openAICompatible

        let service = LLMService(config: config)
        XCTAssertEqual(service.selectedProvider, .openAICompatible)
    }

    func testConfigProviderSwitching() async {
        var config = LLMConfig.default

        // Start with Apple Intelligence (not configured)
        config.provider = .appleIntelligence
        let service1 = LLMService(config: config)
        let configured1 = await service1.isConfigured
        XCTAssertFalse(configured1)

        // Switch to OpenAI-compatible (configured)
        config.provider = .openAICompatible
        config.openAICompatible.model = "llama3.2"
        let service2 = LLMService(config: config)
        let configured2 = await service2.isConfigured
        XCTAssertTrue(configured2)
    }
}
