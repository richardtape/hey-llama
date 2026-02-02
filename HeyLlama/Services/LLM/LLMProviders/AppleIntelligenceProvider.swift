import Foundation

/// Apple Intelligence provider (stub - awaiting public API)
///
/// This provider will integrate with Apple's on-device AI when the API becomes
/// available for third-party developers. For now, it returns unavailable status.
actor AppleIntelligenceProvider: LLMServiceProtocol {
    private let config: AppleIntelligenceConfig
    private let systemPromptTemplate: String

    /// Check if Apple Intelligence is available on this device
    /// This will be updated when Apple releases the public API
    nonisolated var isAvailable: Bool {
        // TODO: Check for macOS version and device capability
        // For now, always return false as API is not yet available
        return false
    }

    var isConfigured: Bool {
        config.enabled && isAvailable
    }

    init(config: AppleIntelligenceConfig, systemPromptTemplate: String = LLMConfig.defaultSystemPrompt) {
        self.config = config
        self.systemPromptTemplate = systemPromptTemplate
    }

    func complete(
        prompt: String,
        context: CommandContext?,
        conversationHistory: [ConversationTurn]
    ) async throws -> String {
        guard config.enabled else {
            throw LLMError.notConfigured
        }

        guard isAvailable else {
            throw LLMError.providerUnavailable(
                "Apple Intelligence is not yet available. " +
                "Please configure an OpenAI-compatible provider in settings."
            )
        }

        // TODO: Implement actual Apple Intelligence API call when available
        // This will use Foundation.LanguageModel or similar API

        throw LLMError.providerUnavailable("Apple Intelligence API not implemented")
    }
}
