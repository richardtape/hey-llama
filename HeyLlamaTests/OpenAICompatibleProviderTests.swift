import XCTest
@testable import HeyLlama

final class OpenAICompatibleProviderTests: XCTestCase {

    func testIsConfiguredWhenModelSet() async {
        var config = OpenAICompatibleConfig()
        config.model = "llama3.2"
        config.baseURL = "http://localhost:11434/v1"

        let provider = OpenAICompatibleProvider(config: config)
        let configured = await provider.isConfigured
        XCTAssertTrue(configured)
    }

    func testIsNotConfiguredWhenModelEmpty() async {
        var config = OpenAICompatibleConfig()
        config.model = ""
        config.baseURL = "http://localhost:11434/v1"

        let provider = OpenAICompatibleProvider(config: config)
        let configured = await provider.isConfigured
        XCTAssertFalse(configured)
    }

    func testIsNotConfiguredWhenBaseURLEmpty() async {
        var config = OpenAICompatibleConfig()
        config.model = "llama3.2"
        config.baseURL = ""

        let provider = OpenAICompatibleProvider(config: config)
        let configured = await provider.isConfigured
        XCTAssertFalse(configured)
    }

    func testBuildRequestBodyWithoutHistory() throws {
        var config = OpenAICompatibleConfig()
        config.model = "llama3.2"

        let provider = OpenAICompatibleProvider(config: config)
        let body = provider.buildRequestBody(
            systemPrompt: "You are helpful.",
            prompt: "What time is it?",
            conversationHistory: []
        )

        // Verify structure
        XCTAssertEqual(body["model"] as? String, "llama3.2")

        let messages = body["messages"] as? [[String: String]]
        XCTAssertNotNil(messages)
        XCTAssertEqual(messages?.count, 2) // system + user

        XCTAssertEqual(messages?[0]["role"], "system")
        XCTAssertEqual(messages?[0]["content"], "You are helpful.")

        XCTAssertEqual(messages?[1]["role"], "user")
        XCTAssertEqual(messages?[1]["content"], "What time is it?")
    }

    func testBuildRequestBodyWithHistory() throws {
        var config = OpenAICompatibleConfig()
        config.model = "llama3.2"

        let provider = OpenAICompatibleProvider(config: config)

        let history = [
            ConversationTurn(role: .user, content: "Capital of France?"),
            ConversationTurn(role: .assistant, content: "Paris")
        ]

        let body = provider.buildRequestBody(
            systemPrompt: "You are helpful.",
            prompt: "What language there?",
            conversationHistory: history
        )

        let messages = body["messages"] as? [[String: String]]
        XCTAssertNotNil(messages)
        XCTAssertEqual(messages?.count, 4) // system + 2 history + current user

        // Verify order: system, history, current prompt
        XCTAssertEqual(messages?[0]["role"], "system")
        XCTAssertEqual(messages?[1]["role"], "user")
        XCTAssertEqual(messages?[1]["content"], "Capital of France?")
        XCTAssertEqual(messages?[2]["role"], "assistant")
        XCTAssertEqual(messages?[2]["content"], "Paris")
        XCTAssertEqual(messages?[3]["role"], "user")
        XCTAssertEqual(messages?[3]["content"], "What language there?")
    }

    func testBuildSystemPromptWithSpeakerName() {
        let config = OpenAICompatibleConfig()
        let provider = OpenAICompatibleProvider(config: config)

        let template = "Hello {speaker_name}, how can I help?"
        let result = provider.buildSystemPrompt(template: template, speakerName: "Alice")

        XCTAssertEqual(result, "Hello Alice, how can I help?")
    }

    func testBuildSystemPromptWithGuestWhenNil() {
        let config = OpenAICompatibleConfig()
        let provider = OpenAICompatibleProvider(config: config)

        let template = "Hello {speaker_name}, how can I help?"
        let result = provider.buildSystemPrompt(template: template, speakerName: nil)

        XCTAssertEqual(result, "Hello Guest, how can I help?")
    }

    func testParseResponseExtractsContent() throws {
        let config = OpenAICompatibleConfig()
        let provider = OpenAICompatibleProvider(config: config)

        let responseJSON = """
        {
            "id": "chatcmpl-123",
            "choices": [{
                "index": 0,
                "message": {
                    "role": "assistant",
                    "content": "The time is 3:30 PM."
                },
                "finish_reason": "stop"
            }]
        }
        """

        let data = responseJSON.data(using: .utf8)!
        let content = try provider.parseResponse(data)

        XCTAssertEqual(content, "The time is 3:30 PM.")
    }

    func testParseResponseThrowsOnInvalidJSON() {
        let config = OpenAICompatibleConfig()
        let provider = OpenAICompatibleProvider(config: config)

        let invalidData = "not json".data(using: .utf8)!

        XCTAssertThrowsError(try provider.parseResponse(invalidData)) { error in
            XCTAssertTrue(error is LLMError)
        }
    }

    func testParseResponseThrowsOnMissingChoices() {
        let config = OpenAICompatibleConfig()
        let provider = OpenAICompatibleProvider(config: config)

        let responseJSON = """
        {
            "id": "chatcmpl-123",
            "choices": []
        }
        """

        let data = responseJSON.data(using: .utf8)!

        XCTAssertThrowsError(try provider.parseResponse(data)) { error in
            XCTAssertTrue(error is LLMError)
        }
    }
}
