import Foundation
@testable import HeyLlama

actor MockLLMService: LLMServiceProtocol {
    private var _isConfigured: Bool = true
    private var mockResponse: String = ""
    private var mockError: Error?

    private(set) var lastPrompt: String?
    private(set) var lastContext: CommandContext?
    private(set) var lastConversationHistory: [ConversationTurn] = []
    private(set) var completionCount: Int = 0

    var isConfigured: Bool {
        _isConfigured
    }

    func setConfigured(_ configured: Bool) {
        _isConfigured = configured
    }

    func setMockResponse(_ response: String) {
        self.mockResponse = response
        self.mockError = nil
    }

    func setMockError(_ error: Error) {
        self.mockError = error
    }

    func complete(
        prompt: String,
        context: CommandContext?,
        conversationHistory: [ConversationTurn]
    ) async throws -> String {
        lastPrompt = prompt
        lastContext = context
        lastConversationHistory = conversationHistory
        completionCount += 1

        if let error = mockError {
            throw error
        }

        return mockResponse
    }

    func resetCallTracking() {
        lastPrompt = nil
        lastContext = nil
        lastConversationHistory = []
        completionCount = 0
    }
}
