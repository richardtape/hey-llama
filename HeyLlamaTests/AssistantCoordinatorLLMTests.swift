import XCTest
@testable import HeyLlama

final class AssistantCoordinatorLLMTests: XCTestCase {

    @MainActor
    func testConversationManagerIntegration() async {
        let manager = ConversationManager(timeoutMinutes: 5, maxTurns: 10)

        // Simulate conversation
        manager.addTurn(role: .user, content: "What's the capital of France?")
        manager.addTurn(role: .assistant, content: "Paris")
        manager.addTurn(role: .user, content: "What language do they speak?")

        let history = manager.getRecentHistory()
        XCTAssertEqual(history.count, 3)
    }

    func testMockLLMServiceIntegration() async throws {
        let mockLLM = MockLLMService()
        await mockLLM.setMockResponse("It's 3:30 PM")

        let history = [
            ConversationTurn(role: .user, content: "Hello"),
            ConversationTurn(role: .assistant, content: "Hi!")
        ]

        let response = try await mockLLM.complete(
            prompt: "What time is it?",
            context: nil,
            conversationHistory: history
        )

        XCTAssertEqual(response, "It's 3:30 PM")

        let lastHistory = await mockLLM.lastConversationHistory
        XCTAssertEqual(lastHistory.count, 2)
    }

    func testOpenAIProviderRequestBodyStructure() {
        var config = OpenAICompatibleConfig()
        config.model = "llama3.2"

        let provider = OpenAICompatibleProvider(config: config)

        let history = [
            ConversationTurn(role: .user, content: "Hello"),
            ConversationTurn(role: .assistant, content: "Hi there!")
        ]

        let body = provider.buildRequestBody(
            systemPrompt: "Be helpful.",
            skillsManifest: nil,
            prompt: "How are you?",
            conversationHistory: history
        )

        let messages = body["messages"] as? [[String: String]]
        XCTAssertNotNil(messages)

        // Should have: system + history (2) + current prompt = 4 messages
        XCTAssertEqual(messages?.count, 4)

        // Verify message order
        XCTAssertEqual(messages?[0]["role"], "system")
        XCTAssertEqual(messages?[1]["role"], "user")
        XCTAssertEqual(messages?[1]["content"], "Hello")
        XCTAssertEqual(messages?[2]["role"], "assistant")
        XCTAssertEqual(messages?[2]["content"], "Hi there!")
        XCTAssertEqual(messages?[3]["role"], "user")
        XCTAssertEqual(messages?[3]["content"], "How are you?")
    }

    func testLLMConfigPersistence() throws {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

        defer {
            try? FileManager.default.removeItem(at: tempDirectory)
        }

        let store = ConfigStore(baseDirectory: tempDirectory)

        var config = AssistantConfig.default
        config.llm.provider = .openAICompatible
        config.llm.openAICompatible.model = "llama3.2"
        config.llm.openAICompatible.baseURL = "http://localhost:11434/v1"
        config.llm.conversationTimeoutMinutes = 10

        try store.saveConfig(config)
        let loaded = store.loadConfig()

        XCTAssertEqual(loaded.llm.provider, .openAICompatible)
        XCTAssertEqual(loaded.llm.openAICompatible.model, "llama3.2")
        XCTAssertEqual(loaded.llm.conversationTimeoutMinutes, 10)
    }
}
