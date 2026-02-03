import Foundation

/// Main LLM service that delegates to the configured provider
actor LLMService: LLMServiceProtocol {
    private let config: LLMConfig
    private let appleIntelligenceProvider: AppleIntelligenceProvider
    private let openAICompatibleProvider: OpenAICompatibleProvider

    /// The currently selected provider type
    nonisolated var selectedProvider: LLMProvider {
        config.provider
    }

    var isConfigured: Bool {
        get async {
            switch config.provider {
            case .appleIntelligence:
                return await appleIntelligenceProvider.isConfigured
            case .openAICompatible:
                return await openAICompatibleProvider.isConfigured
            }
        }
    }

    init(config: LLMConfig) {
        self.config = config
        self.appleIntelligenceProvider = AppleIntelligenceProvider(
            config: config.appleIntelligence,
            systemPromptTemplate: config.systemPrompt
        )
        self.openAICompatibleProvider = OpenAICompatibleProvider(
            config: config.openAICompatible,
            systemPromptTemplate: config.systemPrompt
        )
    }

    func complete(
        prompt: String,
        context: CommandContext?,
        conversationHistory: [ConversationTurn],
        skillsManifest: String?
    ) async throws -> String {
        switch config.provider {
        case .appleIntelligence:
            return try await appleIntelligenceProvider.complete(
                prompt: prompt,
                context: context,
                conversationHistory: conversationHistory,
                skillsManifest: skillsManifest
            )
        case .openAICompatible:
            return try await openAICompatibleProvider.complete(
                prompt: prompt,
                context: context,
                conversationHistory: conversationHistory,
                skillsManifest: skillsManifest
            )
        }
    }
}
