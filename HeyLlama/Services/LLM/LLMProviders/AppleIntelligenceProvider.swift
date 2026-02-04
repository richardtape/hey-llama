import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Default system prompt for Apple Intelligence (no JSON - uses native tool calling)
private let appleIntelligenceDefaultSystemPrompt = """
    You are Llama, a helpful voice assistant. Keep responses concise \
    and conversational, suitable for reading on a small UI display. \
    The current user is {speaker_name}. Be friendly but brief. \
    If the user asks for multiple actions or items, call tools multiple times.
    """

/// Apple Intelligence provider using Foundation Models framework
///
/// This provider integrates with Apple's on-device AI powered by the Foundation Models
/// framework introduced in macOS 26 (Tahoe) and iOS 26.
actor AppleIntelligenceProvider: LLMServiceProtocol {
    private let config: AppleIntelligenceConfig

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

    init(config: AppleIntelligenceConfig) {
        self.config = config
    }

    func complete(
        prompt: String,
        context: CommandContext?,
        conversationHistory: [ConversationTurn],
        skillsManifest: String?,
        systemPrompt systemPromptOverride: String?
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
                skillsManifest: skillsManifest,
                systemPromptOverride: systemPromptOverride
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
        skillsManifest: String?,
        systemPromptOverride: String?
    ) async throws -> String {
        // Build the system prompt with speaker name
        let speakerName = context?.speaker?.name ?? "Guest"
        let template = systemPromptOverride ?? appleIntelligenceDefaultSystemPrompt
        let systemPrompt = Self.buildInstructions(
            template: template,
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

    // MARK: - Tool Infrastructure

    #if canImport(FoundationModels)
    @available(macOS 26.0, iOS 26.0, *)
    private func makeTools(
        recorder: ToolInvocationRecorder,
        includeSkills: Bool
    ) -> [any Tool] {
        guard includeSkills else { return [] }

        // Collect tools from registered skills
        var tools: [any Tool] = []

        for skillType in SkillsRegistry.allSkillTypes {
            if let tool = makeToolForSkill(skillType, recorder: recorder) {
                tools.append(tool)
            }
        }

        return tools
    }

    /// Create an Apple Tool for a skill type.
    ///
    /// When adding a new skill, add a case here to return its tool.
    /// The switch is necessary because Swift can't dynamically instantiate
    /// `@Generable` types from protocol metadata.
    ///
    /// ## Adding a New Skill Tool
    ///
    /// 1. Create a new Tool struct below (e.g., `CalendarTool`)
    /// 2. Add a case in this switch to return it
    /// 3. The tool's Arguments must have `@Generable` for guided generation
    @available(macOS 26.0, iOS 26.0, *)
    private func makeToolForSkill(
        _ skillType: any Skill.Type,
        recorder: ToolInvocationRecorder
    ) -> (any Tool)? {
        switch skillType {
        case is WeatherForecastSkill.Type:
            return WeatherForecastTool(recorder: recorder)
        case is RemindersAddItemSkill.Type:
            return RemindersAddItemTool(recorder: recorder)
        case is RemindersRemoveItemSkill.Type:
            return RemindersRemoveItemTool(recorder: recorder)
        case is RemindersCompleteItemSkill.Type:
            return RemindersCompleteItemTool(recorder: recorder)
        case is RemindersReadItemsSkill.Type:
            return RemindersReadItemsTool(recorder: recorder)
        case is AppleMusicPlaySkill.Type:
            return AppleMusicPlayTool(recorder: recorder)
        case is AppleMusicPlayShuffledSkill.Type:
            return AppleMusicPlayShuffledTool(recorder: recorder)
        case is AppleMusicAddToPlaylistSkill.Type:
            return AppleMusicAddToPlaylistTool(recorder: recorder)
        case is AppleMusicNowPlayingSkill.Type:
            return AppleMusicNowPlayingTool(recorder: recorder)
        case is AppleMusicControlSkill.Type:
            return AppleMusicControlTool(recorder: recorder)
        // Future skills:
        // case is CalendarSkill.Type:
        //     return CalendarTool(recorder: recorder)
        default:
            print("Warning: No Apple Tool registered for skill: \(skillType.id)")
            return nil
        }
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

    // MARK: - Skill Tools

    /// Weather forecast tool for Apple's Foundation Models.
    ///
    /// Uses metadata from `WeatherForecastSkill` and `@Generable` Arguments
    /// for guided generation.
    @available(macOS 26.0, iOS 26.0, *)
    struct WeatherForecastTool: Tool {
        let name: String = WeatherForecastSkill.id
        let description: String = WeatherForecastSkill.skillDescription
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

    /// Reminders add item tool for Apple's Foundation Models.
    ///
    /// Uses metadata from `RemindersAddItemSkill` and `@Generable` Arguments
    /// for guided generation.
    @available(macOS 26.0, iOS 26.0, *)
    struct RemindersAddItemTool: Tool {
        let name: String = RemindersAddItemSkill.id
        let description: String = RemindersAddItemSkill.skillDescription
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

    /// Reminders remove item tool for Apple's Foundation Models.
    @available(macOS 26.0, iOS 26.0, *)
    struct RemindersRemoveItemTool: Tool {
        let name: String = RemindersRemoveItemSkill.id
        let description: String = RemindersRemoveItemSkill.skillDescription
        let recorder: ToolInvocationRecorder

        @Generable
        struct Arguments: ConvertibleFromGeneratedContent {
            var listName: String
            var itemName: String
        }

        func call(arguments: Arguments) async throws -> String {
            let args: [String: Any] = [
                "listName": arguments.listName,
                "itemName": arguments.itemName
            ]
            await recorder.record(ToolInvocation(skillId: name, arguments: args))
            return "OK"
        }
    }

    /// Reminders complete item tool for Apple's Foundation Models.
    @available(macOS 26.0, iOS 26.0, *)
    struct RemindersCompleteItemTool: Tool {
        let name: String = RemindersCompleteItemSkill.id
        let description: String = RemindersCompleteItemSkill.skillDescription
        let recorder: ToolInvocationRecorder

        @Generable
        struct Arguments: ConvertibleFromGeneratedContent {
            var listName: String
            var itemName: String
        }

        func call(arguments: Arguments) async throws -> String {
            let args: [String: Any] = [
                "listName": arguments.listName,
                "itemName": arguments.itemName
            ]
            await recorder.record(ToolInvocation(skillId: name, arguments: args))
            return "OK"
        }
    }

    /// Reminders read items tool for Apple's Foundation Models.
    @available(macOS 26.0, iOS 26.0, *)
    struct RemindersReadItemsTool: Tool {
        let name: String = RemindersReadItemsSkill.id
        let description: String = RemindersReadItemsSkill.skillDescription
        let recorder: ToolInvocationRecorder

        @Generable
        struct Arguments: ConvertibleFromGeneratedContent {
            var listName: String
            var status: String?
        }

        func call(arguments: Arguments) async throws -> String {
            var args: [String: Any] = [
                "listName": arguments.listName
            ]
            if let status = arguments.status, !status.isEmpty {
                args["status"] = status
            }
            await recorder.record(ToolInvocation(skillId: name, arguments: args))
            return "OK"
        }
    }

    /// Apple Music play tool for Apple's Foundation Models.
    @available(macOS 26.0, iOS 26.0, *)
    struct AppleMusicPlayTool: Tool {
        let name: String = AppleMusicPlaySkill.id
        let description: String = AppleMusicPlaySkill.skillDescription
        let recorder: ToolInvocationRecorder

        @Generable
        struct Arguments: ConvertibleFromGeneratedContent {
            var query: String
            var entityType: String
            var source: String?
            var shuffle: Bool?
        }

        func call(arguments: Arguments) async throws -> String {
            var args: [String: Any] = [
                "query": arguments.query,
                "entityType": arguments.entityType
            ]
            if let source = arguments.source, !source.isEmpty {
                args["source"] = source
            }
            if let shuffle = arguments.shuffle {
                args["shuffle"] = shuffle
            }
            await recorder.record(ToolInvocation(skillId: name, arguments: args))
            return "OK"
        }
    }

    /// Apple Music play shuffled tool for Apple's Foundation Models.
    @available(macOS 26.0, iOS 26.0, *)
    struct AppleMusicPlayShuffledTool: Tool {
        let name: String = AppleMusicPlayShuffledSkill.id
        let description: String = AppleMusicPlayShuffledSkill.skillDescription
        let recorder: ToolInvocationRecorder

        @Generable
        struct Arguments: ConvertibleFromGeneratedContent {
            var query: String
            var entityType: String
            var source: String?
        }

        func call(arguments: Arguments) async throws -> String {
            var args: [String: Any] = [
                "query": arguments.query,
                "entityType": arguments.entityType
            ]
            if let source = arguments.source, !source.isEmpty {
                args["source"] = source
            }
            await recorder.record(ToolInvocation(skillId: name, arguments: args))
            return "OK"
        }
    }

    /// Apple Music add-to-playlist tool for Apple's Foundation Models.
    @available(macOS 26.0, iOS 26.0, *)
    struct AppleMusicAddToPlaylistTool: Tool {
        let name: String = AppleMusicAddToPlaylistSkill.id
        let description: String = AppleMusicAddToPlaylistSkill.skillDescription
        let recorder: ToolInvocationRecorder

        @Generable
        struct Arguments: ConvertibleFromGeneratedContent {
            var trackQuery: String
            var playlistName: String
            var source: String?
        }

        func call(arguments: Arguments) async throws -> String {
            var args: [String: Any] = [
                "trackQuery": arguments.trackQuery,
                "playlistName": arguments.playlistName
            ]
            if let source = arguments.source, !source.isEmpty {
                args["source"] = source
            }
            await recorder.record(ToolInvocation(skillId: name, arguments: args))
            return "OK"
        }
    }

    /// Apple Music now playing tool for Apple's Foundation Models.
    @available(macOS 26.0, iOS 26.0, *)
    struct AppleMusicNowPlayingTool: Tool {
        let name: String = AppleMusicNowPlayingSkill.id
        let description: String = AppleMusicNowPlayingSkill.skillDescription
        let recorder: ToolInvocationRecorder

        @Generable
        struct Arguments: ConvertibleFromGeneratedContent {}

        func call(arguments: Arguments) async throws -> String {
            await recorder.record(ToolInvocation(skillId: name, arguments: [:]))
            return "OK"
        }
    }

    /// Apple Music control tool for Apple's Foundation Models.
    @available(macOS 26.0, iOS 26.0, *)
    struct AppleMusicControlTool: Tool {
        let name: String = AppleMusicControlSkill.id
        let description: String = AppleMusicControlSkill.skillDescription
        let recorder: ToolInvocationRecorder

        @Generable
        struct Arguments: ConvertibleFromGeneratedContent {
            var action: String
            var mode: String?
        }

        func call(arguments: Arguments) async throws -> String {
            var args: [String: Any] = [
                "action": arguments.action
            ]
            if let mode = arguments.mode, !mode.isEmpty {
                args["mode"] = mode
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
