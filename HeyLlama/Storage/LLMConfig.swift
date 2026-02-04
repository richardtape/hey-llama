import Foundation

/// LLM provider selection
enum LLMProvider: String, Codable, CaseIterable, Sendable {
    case appleIntelligence
    case openAICompatible
}

/// Apple Intelligence configuration
struct AppleIntelligenceConfig: Codable, Equatable, Sendable {
    var enabled: Bool
    var preferredModel: String?

    nonisolated init(enabled: Bool = true, preferredModel: String? = nil) {
        self.enabled = enabled
        self.preferredModel = preferredModel
    }
}

/// OpenAI-compatible API configuration (Ollama, LM Studio, etc.)
struct OpenAICompatibleConfig: Codable, Equatable, Sendable {
    var enabled: Bool
    var baseURL: String
    var apiKey: String?
    var model: String
    var timeoutSeconds: Int

    nonisolated init(
        enabled: Bool = true,
        baseURL: String = "http://localhost:11434/v1",
        apiKey: String? = nil,
        model: String = "",
        timeoutSeconds: Int = 60
    ) {
        self.enabled = enabled
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.model = model
        self.timeoutSeconds = timeoutSeconds
    }

    /// Returns true if minimum configuration is set (baseURL + model)
    var isConfigured: Bool {
        !baseURL.isEmpty && !model.isEmpty
    }
}

// Default system prompt as a module-level constant for nonisolated access
private nonisolated let llmDefaultSystemPrompt = """
    You are Llama, a helpful voice assistant. Keep responses concise \
    and conversational, suitable for reading on a small UI display. \
    The current user is {speaker_name}. Be friendly but brief. \
    You must respond with a single JSON object only. Do not wrap in \
    code fences or add extra text. Never put tool call JSON inside \
    the "text" field.
    """

/// Complete LLM configuration
struct LLMConfig: Equatable, Sendable {
    var provider: LLMProvider
    var systemPrompt: String
    var appleIntelligence: AppleIntelligenceConfig
    var openAICompatible: OpenAICompatibleConfig
    var conversationTimeoutMinutes: Int
    var maxConversationTurns: Int
    var followUpWindowSeconds: Int
    var conversationClosingPhrases: [String]

    /// Default system prompt for the assistant
    static var defaultSystemPrompt: String { llmDefaultSystemPrompt }

    nonisolated init(
        provider: LLMProvider = .appleIntelligence,
        systemPrompt: String? = nil,
        appleIntelligence: AppleIntelligenceConfig = AppleIntelligenceConfig(),
        openAICompatible: OpenAICompatibleConfig = OpenAICompatibleConfig(),
        conversationTimeoutMinutes: Int = 5,
        maxConversationTurns: Int = 10,
        followUpWindowSeconds: Int = 15,
        conversationClosingPhrases: [String] = [
            "thanks",
            "thank you",
            "thanks llama",
            "thank you llama",
            "that's all",
            "that is all",
            "that's it",
            "that is it",
            "goodbye",
            "bye",
            "stop",
            "stop listening",
            "cancel"
        ]
    ) {
        self.provider = provider
        self.systemPrompt = systemPrompt ?? llmDefaultSystemPrompt
        self.appleIntelligence = appleIntelligence
        self.openAICompatible = openAICompatible
        self.conversationTimeoutMinutes = conversationTimeoutMinutes
        self.maxConversationTurns = maxConversationTurns
        self.followUpWindowSeconds = followUpWindowSeconds
        self.conversationClosingPhrases = conversationClosingPhrases
    }

    nonisolated static var `default`: LLMConfig {
        LLMConfig()
    }
}

// MARK: - Codable conformance with nonisolated methods
extension LLMConfig: Codable {
    private enum CodingKeys: String, CodingKey {
        case provider, systemPrompt, appleIntelligence, openAICompatible
        case conversationTimeoutMinutes, maxConversationTurns
        case followUpWindowSeconds, conversationClosingPhrases
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        provider = try container.decode(LLMProvider.self, forKey: .provider)
        systemPrompt = try container.decode(String.self, forKey: .systemPrompt)
        appleIntelligence = try container.decode(AppleIntelligenceConfig.self, forKey: .appleIntelligence)
        openAICompatible = try container.decode(OpenAICompatibleConfig.self, forKey: .openAICompatible)
        conversationTimeoutMinutes = try container.decode(Int.self, forKey: .conversationTimeoutMinutes)
        maxConversationTurns = try container.decode(Int.self, forKey: .maxConversationTurns)
        followUpWindowSeconds = try container.decodeIfPresent(Int.self, forKey: .followUpWindowSeconds) ?? 15
        conversationClosingPhrases = try container.decodeIfPresent([String].self, forKey: .conversationClosingPhrases) ?? [
            "thanks",
            "thank you",
            "thanks llama",
            "thank you llama",
            "that's all",
            "that is all",
            "that's it",
            "that is it",
            "goodbye",
            "bye",
            "stop",
            "stop listening",
            "cancel"
        ]
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(provider, forKey: .provider)
        try container.encode(systemPrompt, forKey: .systemPrompt)
        try container.encode(appleIntelligence, forKey: .appleIntelligence)
        try container.encode(openAICompatible, forKey: .openAICompatible)
        try container.encode(conversationTimeoutMinutes, forKey: .conversationTimeoutMinutes)
        try container.encode(maxConversationTurns, forKey: .maxConversationTurns)
        try container.encode(followUpWindowSeconds, forKey: .followUpWindowSeconds)
        try container.encode(conversationClosingPhrases, forKey: .conversationClosingPhrases)
    }
}
