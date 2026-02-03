import Foundation
@testable import HeyLlama

actor MockLLMService: LLMServiceProtocol {
    private var _isConfigured: Bool = true
    private var mockResponse: String = ""
    private var mockResponses: [String] = []
    private var mockError: Error?

    private(set) var lastPrompt: String?
    private(set) var lastContext: CommandContext?
    private(set) var lastConversationHistory: [ConversationTurn] = []
    private(set) var lastSkillsManifest: String?
    private(set) var lastSystemPrompt: String?
    private(set) var completionCount: Int = 0

    var isConfigured: Bool {
        _isConfigured
    }

    func setConfigured(_ configured: Bool) {
        _isConfigured = configured
    }

    func setMockResponse(_ response: String) {
        self.mockResponse = response
        self.mockResponses = []
        self.mockError = nil
    }

    func setMockResponses(_ responses: [String]) {
        self.mockResponses = responses
        self.mockError = nil
    }

    func setMockError(_ error: Error) {
        self.mockError = error
    }

    func complete(
        prompt: String,
        context: CommandContext?,
        conversationHistory: [ConversationTurn],
        skillsManifest: String?,
        systemPrompt: String?
    ) async throws -> String {
        lastPrompt = prompt
        lastContext = context
        lastConversationHistory = conversationHistory
        lastSkillsManifest = skillsManifest
        lastSystemPrompt = systemPrompt
        completionCount += 1

        if let error = mockError {
            throw error
        }

        if !mockResponses.isEmpty {
            return mockResponses.removeFirst()
        }

        return mockResponse
    }

    func resetCallTracking() {
        lastPrompt = nil
        lastContext = nil
        lastConversationHistory = []
        lastSkillsManifest = nil
        lastSystemPrompt = nil
        completionCount = 0
    }
}
