import Foundation

/// Errors that can occur during LLM operations
enum LLMError: Error, Equatable, LocalizedError {
    case notConfigured
    case networkError(String)
    case apiError(statusCode: Int, message: String)
    case responseParseError(String)
    case providerUnavailable(String)
    case timeout

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "LLM provider is not configured"
        case .networkError(let message):
            return "Network error: \(message)"
        case .apiError(let statusCode, let message):
            return "API error (\(statusCode)): \(message)"
        case .responseParseError(let message):
            return "Failed to parse response: \(message)"
        case .providerUnavailable(let message):
            return "Provider unavailable: \(message)"
        case .timeout:
            return "Request timed out"
        }
    }
}

/// Protocol for LLM service implementations
protocol LLMServiceProtocol: Sendable {
    /// Whether the service is properly configured and ready to use
    var isConfigured: Bool { get async }

    /// Complete a prompt with optional conversation context
    /// - Parameters:
    ///   - prompt: The user's command/question
    ///   - context: Optional command context including speaker info
    ///   - conversationHistory: Previous conversation turns for multi-turn context
    /// - Returns: The LLM's response text
    func complete(
        prompt: String,
        context: CommandContext?,
        conversationHistory: [ConversationTurn]
    ) async throws -> String
}

/// Extension with convenience method
extension LLMServiceProtocol {
    func complete(prompt: String, context: CommandContext?) async throws -> String {
        try await complete(prompt: prompt, context: context, conversationHistory: [])
    }
}
