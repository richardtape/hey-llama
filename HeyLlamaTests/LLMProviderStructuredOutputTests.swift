import XCTest
@testable import HeyLlama

final class LLMProviderStructuredOutputTests: XCTestCase {

    // MARK: - System Prompt Tests

    func testOpenAIProviderIncludesSkillsManifestInPrompt() {
        let config = OpenAICompatibleConfig(
            enabled: true,
            baseURL: "http://localhost:11434/v1",
            model: "llama3.2"
        )

        let skillsManifest = "Available skills: weather.forecast"
        let systemPrompt = "You are Llama"

        let provider = OpenAICompatibleProvider(
            config: config,
            systemPromptTemplate: systemPrompt
        )

        // Build request body with skills manifest
        let body = provider.buildRequestBody(
            systemPrompt: systemPrompt,
            skillsManifest: skillsManifest,
            prompt: "What's the weather?",
            conversationHistory: []
        )

        let messages = body["messages"] as? [[String: String]]
        XCTAssertNotNil(messages)

        // System message should include skills manifest
        let systemMessage = messages?.first { $0["role"] == "system" }
        XCTAssertNotNil(systemMessage)
        XCTAssertTrue(systemMessage?["content"]?.contains("weather.forecast") ?? false)
    }

    func testOpenAIProviderRequestBodyStructure() {
        let config = OpenAICompatibleConfig(
            enabled: true,
            baseURL: "http://localhost:11434/v1",
            model: "llama3.2"
        )

        let provider = OpenAICompatibleProvider(
            config: config,
            systemPromptTemplate: "You are Llama"
        )

        let body = provider.buildRequestBody(
            systemPrompt: "You are Llama",
            skillsManifest: nil,
            prompt: "Hello",
            conversationHistory: []
        )

        XCTAssertEqual(body["model"] as? String, "llama3.2")
        XCTAssertNotNil(body["messages"])
    }

    func testOpenAIProviderRequestBodyWithoutManifest() {
        let config = OpenAICompatibleConfig(
            enabled: true,
            baseURL: "http://localhost:11434/v1",
            model: "llama3.2"
        )

        let provider = OpenAICompatibleProvider(
            config: config,
            systemPromptTemplate: "You are Llama"
        )

        let body = provider.buildRequestBody(
            systemPrompt: "You are Llama",
            skillsManifest: nil,
            prompt: "Hello",
            conversationHistory: []
        )

        let messages = body["messages"] as? [[String: String]]
        let systemMessage = messages?.first { $0["role"] == "system" }

        // System message should NOT contain "SKILLS" section when manifest is nil
        XCTAssertFalse(systemMessage?["content"]?.contains("--- SKILLS ---") ?? true)
    }

    // MARK: - Response Format Tests

    func testParseValidJSONResponse() throws {
        let config = OpenAICompatibleConfig(
            enabled: true,
            baseURL: "http://localhost:11434/v1",
            model: "llama3.2"
        )

        let provider = OpenAICompatibleProvider(config: config, systemPromptTemplate: "")

        // Simulate a response that contains JSON
        let responseJSON = """
        {
            "choices": [{
                "message": {
                    "content": "{\\"type\\":\\"respond\\",\\"text\\":\\"Hello!\\"}"
                }
            }]
        }
        """.data(using: .utf8)!

        let content = try provider.parseResponse(responseJSON)
        XCTAssertTrue(content.contains("respond"))
        XCTAssertTrue(content.contains("Hello!"))
    }

    func testParseSimpleTextResponse() throws {
        let config = OpenAICompatibleConfig(
            enabled: true,
            baseURL: "http://localhost:11434/v1",
            model: "llama3.2"
        )

        let provider = OpenAICompatibleProvider(config: config, systemPromptTemplate: "")

        let responseJSON = """
        {
            "choices": [{
                "message": {
                    "content": "Hello, how can I help you today?"
                }
            }]
        }
        """.data(using: .utf8)!

        let content = try provider.parseResponse(responseJSON)
        XCTAssertEqual(content, "Hello, how can I help you today?")
    }

    // MARK: - Mock LLM Service Tests

    func testMockLLMServiceTracksSkillsManifest() async throws {
        let mockLLM = MockLLMService()
        await mockLLM.setMockResponse("test response")

        let manifest = "Test manifest"
        _ = try await mockLLM.complete(
            prompt: "test",
            context: nil,
            conversationHistory: [],
            skillsManifest: manifest
        )

        let lastManifest = await mockLLM.lastSkillsManifest
        XCTAssertEqual(lastManifest, manifest)
    }

    func testMockLLMServiceTracksNilManifest() async throws {
        let mockLLM = MockLLMService()
        await mockLLM.setMockResponse("test response")

        _ = try await mockLLM.complete(
            prompt: "test",
            context: nil,
            conversationHistory: [],
            skillsManifest: nil
        )

        let lastManifest = await mockLLM.lastSkillsManifest
        XCTAssertNil(lastManifest)
    }
}
