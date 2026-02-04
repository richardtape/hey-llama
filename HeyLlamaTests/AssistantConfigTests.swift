import XCTest
@testable import HeyLlama

final class AssistantConfigTests: XCTestCase {

    func testAssistantConfigDefaults() {
        let config = AssistantConfig.default
        XCTAssertEqual(config.wakePhrase, "hey llama")
        XCTAssertEqual(config.wakeWordSensitivity, 0.5)
        XCTAssertEqual(config.apiPort, 8765)
        XCTAssertTrue(config.apiEnabled)
        XCTAssertTrue(config.audio.autoSwitchOutputForMusic)
    }

    func testAssistantConfigHasLLMConfig() {
        let config = AssistantConfig.default
        XCTAssertEqual(config.llm.provider, .appleIntelligence)
    }

    func testAssistantConfigCodable() throws {
        var config = AssistantConfig.default
        config.wakePhrase = "ok computer"
        config.llm.provider = .openAICompatible
        config.llm.openAICompatible.model = "llama3.2"
        config.audio.preferredOutputDeviceUID = "test-output"
        config.audio.autoSwitchOutputForMusic = false

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(config)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AssistantConfig.self, from: data)

        XCTAssertEqual(decoded.wakePhrase, "ok computer")
        XCTAssertEqual(decoded.llm.provider, .openAICompatible)
        XCTAssertEqual(decoded.llm.openAICompatible.model, "llama3.2")
        XCTAssertEqual(decoded.audio.preferredOutputDeviceUID, "test-output")
        XCTAssertEqual(decoded.audio.autoSwitchOutputForMusic, false)
    }

    func testAssistantConfigEquatable() {
        let config1 = AssistantConfig.default
        let config2 = AssistantConfig.default
        XCTAssertEqual(config1, config2)

        var config3 = AssistantConfig.default
        config3.wakePhrase = "different"
        XCTAssertNotEqual(config1, config3)
    }
}
