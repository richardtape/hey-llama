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

    func testAppleIntelligenceConfiguredMatchesAvailability() async {
        // Apple Intelligence isConfigured should match system availability
        var config = LLMConfig.default
        config.provider = .appleIntelligence

        let service = LLMService(config: config)
        let configured = await service.isConfigured

        // Check actual provider availability
        let provider = AppleIntelligenceProvider(config: config.appleIntelligence)
        XCTAssertEqual(configured, provider.isAvailable,
                       "LLMService.isConfigured should match AppleIntelligenceProvider.isAvailable")
    }

    func testAppleIntelligenceNotConfiguredWhenDisabled() async {
        // Even if Apple Intelligence is available, it should not be configured when disabled
        var config = LLMConfig.default
        config.provider = .appleIntelligence
        config.appleIntelligence.enabled = false

        let service = LLMService(config: config)
        let configured = await service.isConfigured
        XCTAssertFalse(configured, "Should not be configured when disabled")
    }

    func testSelectedProviderReturnsCorrectType() {
        var config = LLMConfig.default
        config.provider = .openAICompatible

        let service = LLMService(config: config)
        XCTAssertEqual(service.selectedProvider, .openAICompatible)
    }

    func testSelectedProviderForAppleIntelligence() {
        var config = LLMConfig.default
        config.provider = .appleIntelligence

        let service = LLMService(config: config)
        XCTAssertEqual(service.selectedProvider, .appleIntelligence)
    }

    func testConfigProviderSwitching() async {
        var config = LLMConfig.default

        // Start with Apple Intelligence
        config.provider = .appleIntelligence
        let service1 = LLMService(config: config)
        let configured1 = await service1.isConfigured

        // Check it matches availability
        let aiProvider = AppleIntelligenceProvider(config: config.appleIntelligence)
        XCTAssertEqual(configured1, aiProvider.isAvailable)

        // Switch to OpenAI-compatible (configured)
        config.provider = .openAICompatible
        config.openAICompatible.model = "llama3.2"
        let service2 = LLMService(config: config)
        let configured2 = await service2.isConfigured
        XCTAssertTrue(configured2)
    }
}
