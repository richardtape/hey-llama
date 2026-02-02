import XCTest
@testable import HeyLlama

final class AppleIntelligenceProviderTests: XCTestCase {

    func testIsConfiguredWhenEnabled() async {
        let config = AppleIntelligenceConfig(enabled: true)
        let provider = AppleIntelligenceProvider(config: config)
        let configured = await provider.isConfigured
        // Currently returns false since API unavailable
        XCTAssertFalse(configured)
    }

    func testIsNotConfiguredWhenDisabled() async {
        let config = AppleIntelligenceConfig(enabled: false)
        let provider = AppleIntelligenceProvider(config: config)
        let configured = await provider.isConfigured
        XCTAssertFalse(configured)
    }

    func testCompleteThrowsUnavailable() async {
        let config = AppleIntelligenceConfig(enabled: true)
        let provider = AppleIntelligenceProvider(config: config)

        do {
            _ = try await provider.complete(prompt: "Test", context: nil, conversationHistory: [])
            XCTFail("Expected error to be thrown")
        } catch let error as LLMError {
            if case .providerUnavailable = error {
                // Expected
            } else {
                XCTFail("Expected providerUnavailable error")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testIsAvailableReturnsFalseCurrently() {
        let config = AppleIntelligenceConfig()
        let provider = AppleIntelligenceProvider(config: config)
        XCTAssertFalse(provider.isAvailable)
    }
}
