import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Apple Intelligence provider using Foundation Models framework
///
/// This provider integrates with Apple's on-device AI powered by the Foundation Models
/// framework introduced in macOS 26 (Tahoe) and iOS 26.
actor AppleIntelligenceProvider: LLMServiceProtocol {
    private let config: AppleIntelligenceConfig
    private let systemPromptTemplate: String

    /// Check if Apple Intelligence is available on this device
    /// Requires macOS 26+ (Tahoe) or iOS 26+ and Apple Silicon
    nonisolated var isAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, iOS 26.0, *) {
            return checkModelAvailability()
        }
        #endif
        return false
    }

    /// Detailed availability status for UI display
    nonisolated var availabilityReason: String {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, iOS 26.0, *) {
            return getAvailabilityReason()
        } else {
            return "Requires macOS 26 (Tahoe) or later"
        }
        #else
        return "Foundation Models framework not available"
        #endif
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
            throw LLMError.providerUnavailable(availabilityReason)
        }

        #if canImport(FoundationModels)
        if #available(macOS 26.0, iOS 26.0, *) {
            return try await performCompletion(
                prompt: prompt,
                context: context,
                conversationHistory: conversationHistory
            )
        }
        #endif

        throw LLMError.providerUnavailable("Foundation Models not available on this platform")
    }

    // MARK: - Private Methods

    #if canImport(FoundationModels)
    @available(macOS 26.0, iOS 26.0, *)
    private nonisolated func checkModelAvailability() -> Bool {
        let model = SystemLanguageModel.default
        switch model.availability {
        case .available:
            return true
        case .unavailable:
            return false
        @unknown default:
            return false
        }
    }

    @available(macOS 26.0, iOS 26.0, *)
    private nonisolated func getAvailabilityReason() -> String {
        let model = SystemLanguageModel.default
        switch model.availability {
        case .available:
            return "Available"
        case .unavailable(let reason):
            switch reason {
            case .deviceNotEligible:
                return "This device does not support Apple Intelligence"
            case .appleIntelligenceNotEnabled:
                return "Apple Intelligence is not enabled in System Settings"
            case .modelNotReady:
                return "Model is downloading or not ready"
            @unknown default:
                return "Apple Intelligence unavailable: \(reason)"
            }
        @unknown default:
            return "Unknown availability status"
        }
    }

    @available(macOS 26.0, iOS 26.0, *)
    private func performCompletion(
        prompt: String,
        context: CommandContext?,
        conversationHistory: [ConversationTurn]
    ) async throws -> String {
        // Build the system prompt with speaker name
        let speakerName = context?.speaker?.name ?? "Guest"
        let systemPrompt = systemPromptTemplate.replacingOccurrences(
            of: "{speaker_name}",
            with: speakerName
        )

        // Create session with instructions
        let session = LanguageModelSession {
            systemPrompt
        }

        // Build the full prompt including conversation history
        let fullPrompt = buildPromptWithHistory(prompt: prompt, history: conversationHistory)

        do {
            let response = try await session.respond(to: fullPrompt)
            return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            // Map Foundation Models errors to our LLMError types
            throw mapError(error)
        }
    }
    #endif

    /// Build prompt with conversation history for context
    private nonisolated func buildPromptWithHistory(
        prompt: String,
        history: [ConversationTurn]
    ) -> String {
        guard !history.isEmpty else {
            return prompt
        }

        // Include recent conversation history as context
        var contextParts: [String] = []
        contextParts.append("Previous conversation:")

        for turn in history {
            let role = turn.role == .user ? "User" : "Assistant"
            contextParts.append("\(role): \(turn.content)")
        }

        contextParts.append("\nCurrent request:")
        contextParts.append("User: \(prompt)")

        return contextParts.joined(separator: "\n")
    }

    #if canImport(FoundationModels)
    @available(macOS 26.0, iOS 26.0, *)
    private nonisolated func mapError(_ error: Error) -> LLMError {
        // Check for specific Foundation Models errors
        if let languageModelError = error as? LanguageModelSession.GenerationError {
            switch languageModelError {
            case .exceededContextWindowSize:
                return .apiError(statusCode: 400, message: "Input too long for model context window")
            case .guardrailViolation:
                return .apiError(statusCode: 400, message: "Content blocked by safety guardrails")
            @unknown default:
                return .apiError(statusCode: 500, message: "Generation error: \(error.localizedDescription)")
            }
        }

        return .networkError(error.localizedDescription)
    }
    #endif
}
