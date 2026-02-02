import XCTest
@testable import HeyLlama

final class MockLLMServiceTests: XCTestCase {

    func testIsConfiguredDefault() async {
        let mock = MockLLMService()
        let configured = await mock.isConfigured
        XCTAssertTrue(configured)
    }

    func testSetNotConfigured() async {
        let mock = MockLLMService()
        await mock.setConfigured(false)
        let configured = await mock.isConfigured
        XCTAssertFalse(configured)
    }

    func testCompletionReturnsMockResponse() async throws {
        let mock = MockLLMService()
        await mock.setMockResponse("The time is 3:30 PM")

        let response = try await mock.complete(prompt: "What time is it?", context: nil)
        XCTAssertEqual(response, "The time is 3:30 PM")
    }

    func testCompletionTracksLastPrompt() async throws {
        let mock = MockLLMService()
        await mock.setMockResponse("Response")

        _ = try await mock.complete(prompt: "Test prompt", context: nil)

        let lastPrompt = await mock.lastPrompt
        XCTAssertEqual(lastPrompt, "Test prompt")
    }

    func testCompletionTracksContext() async throws {
        let mock = MockLLMService()
        await mock.setMockResponse("Response")

        let context = CommandContext(command: "test", source: .localMic)
        _ = try await mock.complete(prompt: "Test", context: context)

        let lastContext = await mock.lastContext
        XCTAssertEqual(lastContext?.command, "test")
    }

    func testCompletionTracksConversationHistory() async throws {
        let mock = MockLLMService()
        await mock.setMockResponse("Response")

        let history = [
            ConversationTurn(role: .user, content: "Hello"),
            ConversationTurn(role: .assistant, content: "Hi!")
        ]

        _ = try await mock.complete(prompt: "Test", context: nil, conversationHistory: history)

        let lastHistory = await mock.lastConversationHistory
        XCTAssertEqual(lastHistory.count, 2)
    }

    func testCompletionThrowsMockError() async {
        let mock = MockLLMService()
        await mock.setMockError(LLMError.notConfigured)

        do {
            _ = try await mock.complete(prompt: "Test", context: nil)
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertEqual(error as? LLMError, .notConfigured)
        }
    }

    func testCompletionCountTracking() async throws {
        let mock = MockLLMService()
        await mock.setMockResponse("Response")

        _ = try await mock.complete(prompt: "One", context: nil)
        _ = try await mock.complete(prompt: "Two", context: nil)
        _ = try await mock.complete(prompt: "Three", context: nil)

        let count = await mock.completionCount
        XCTAssertEqual(count, 3)
    }

    func testResetCallTracking() async throws {
        let mock = MockLLMService()
        await mock.setMockResponse("Response")

        _ = try await mock.complete(prompt: "Test", context: nil)

        await mock.resetCallTracking()

        let count = await mock.completionCount
        let lastPrompt = await mock.lastPrompt

        XCTAssertEqual(count, 0)
        XCTAssertNil(lastPrompt)
    }
}
