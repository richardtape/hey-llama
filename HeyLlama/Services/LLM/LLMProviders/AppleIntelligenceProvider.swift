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

    struct ToolInvocation {
        let skillId: String
        let arguments: [String: Any]
    }

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
        conversationHistory: [ConversationTurn],
        skillsManifest: String?
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
                conversationHistory: conversationHistory,
                skillsManifest: skillsManifest
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
        conversationHistory: [ConversationTurn],
        skillsManifest: String?
    ) async throws -> String {
        // Build the system prompt with speaker name
        let speakerName = context?.speaker?.name ?? "Guest"
        let systemPrompt = Self.buildInstructions(
            template: systemPromptTemplate,
            speakerName: speakerName,
            skillsManifest: skillsManifest,
            useToolCalling: skillsManifest != nil
        )

        // Build the full prompt including conversation history
        let fullPrompt = buildPromptWithHistory(prompt: prompt, history: conversationHistory)

        do {
            let recorder = ToolInvocationRecorder()
            let tools = makeTools(recorder: recorder, includeSkills: skillsManifest != nil)

            let session = LanguageModelSession(
                tools: tools,
                instructions: systemPrompt
            )

            let response = try await session.respond(to: fullPrompt)
            let recordedCalls = await recorder.drain()

            let responseText = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            return try Self.buildActionPlanJSON(responseText: responseText, toolCalls: recordedCalls)
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

    #if canImport(FoundationModels)
    @available(macOS 26.0, iOS 26.0, *)
    private func makeTools(
        recorder: ToolInvocationRecorder,
        includeSkills: Bool
    ) -> [any Tool] {
        guard includeSkills else { return [] }
        return [
            WeatherForecastTool(recorder: recorder),
            RemindersAddItemTool(recorder: recorder)
        ]
    }

    @available(macOS 26.0, iOS 26.0, *)
    actor ToolInvocationRecorder {
        private var calls: [ToolInvocation] = []

        func record(_ call: ToolInvocation) {
            calls.append(call)
        }

        func drain() -> [ToolInvocation] {
            let drained = calls
            calls.removeAll()
            return drained
        }
    }

    @available(macOS 26.0, iOS 26.0, *)
    struct WeatherForecastTool: Tool {
        let name: String = RegisteredSkill.weatherForecast.id
        let description: String = RegisteredSkill.weatherForecast.skillDescription
        let recorder: ToolInvocationRecorder

        @Generable
        struct Arguments: ConvertibleFromGeneratedContent {
            var when: String?
            var location: String?
        }

        func call(arguments: Arguments) async throws -> String {
            let trimmedWhen = arguments.when?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let whenValue = trimmedWhen.isEmpty ? "today" : trimmedWhen
            var args: [String: Any] = ["when": whenValue]

            let trimmedLocation = arguments.location?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !trimmedLocation.isEmpty {
                args["location"] = trimmedLocation
            }
            await recorder.record(ToolInvocation(skillId: name, arguments: args))
            return "OK"
        }
    }

    @available(macOS 26.0, iOS 26.0, *)
    struct RemindersAddItemTool: Tool {
        let name: String = RegisteredSkill.remindersAddItem.id
        let description: String = RegisteredSkill.remindersAddItem.skillDescription
        let recorder: ToolInvocationRecorder

        @Generable
        struct Arguments: ConvertibleFromGeneratedContent {
            var listName: String
            var itemName: String
            var notes: String?
            var dueDateISO8601: String?
        }

        func call(arguments: Arguments) async throws -> String {
            var args: [String: Any] = [
                "listName": arguments.listName,
                "itemName": arguments.itemName
            ]
            if let notes = arguments.notes, !notes.isEmpty {
                args["notes"] = notes
            }
            if let dueDate = arguments.dueDateISO8601, !dueDate.isEmpty {
                args["dueDateISO8601"] = dueDate
            }
            await recorder.record(ToolInvocation(skillId: name, arguments: args))
            return "OK"
        }
    }
    #endif

    static func buildActionPlanJSON(responseText: String, toolCalls: [ToolInvocation]) throws -> String {
        if !toolCalls.isEmpty {
            let calls: [[String: Any]] = toolCalls.map { call in
                [
                    "skillId": call.skillId,
                    "arguments": call.arguments
                ]
            }
            let payload: [String: Any] = [
                "type": "call_skills",
                "calls": calls
            ]
            let data = try JSONSerialization.data(withJSONObject: payload, options: [])
            return String(data: data, encoding: .utf8) ?? "{\"type\":\"call_skills\",\"calls\":[]}"
        }

        let payload: [String: Any] = [
            "type": "respond",
            "text": responseText
        ]
        let data = try JSONSerialization.data(withJSONObject: payload, options: [])
        return String(data: data, encoding: .utf8) ?? "{\"type\":\"respond\",\"text\":\"\"}"
    }

    static func buildInstructions(
        template: String,
        speakerName: String,
        skillsManifest: String?,
        useToolCalling: Bool
    ) -> String {
        var instructions = template.replacingOccurrences(of: "{speaker_name}", with: speakerName)

        if useToolCalling {
            // Remove JSON-only instructions to avoid guardrails with tool calling
            let lines = instructions.split(separator: "\n", omittingEmptySubsequences: false)
            instructions = lines.filter { line in
                !line.lowercased().contains("json")
            }.joined(separator: "\n")
        } else if let manifest = skillsManifest {
            instructions += "\n\n--- SKILLS ---\n\(manifest)"
        }

        return instructions.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension AppleIntelligenceProvider.ToolInvocation: @unchecked Sendable {}
