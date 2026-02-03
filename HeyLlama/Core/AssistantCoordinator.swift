import Foundation
import Combine

@MainActor
final class AssistantCoordinator: ObservableObject {
    @Published private(set) var state: AssistantState = .idle
    @Published private(set) var isListening: Bool = false
    @Published private(set) var audioLevel: Float = 0
    @Published private(set) var lastTranscription: String?
    @Published private(set) var lastCommand: String?
    @Published private(set) var lastResponse: String?
    @Published private(set) var isModelLoading: Bool = false
    @Published private(set) var currentSpeaker: Speaker?
    @Published private(set) var requiresOnboarding: Bool = true
    @Published private(set) var enrolledSpeakers: [Speaker] = []
    @Published private(set) var llmConfigured: Bool = false

    // Skills support
    private(set) var skillsRegistry: SkillsRegistry
    private let permissionManager: SkillPermissionManager

    private let audioEngine: AudioEngine
    private let vadService: VADService
    private let audioBuffer: AudioBuffer
    private let sttService: any STTServiceProtocol
    private let speakerService: any SpeakerServiceProtocol
    private var llmService: any LLMServiceProtocol
    private let commandProcessor: CommandProcessor
    private let speakerStore: SpeakerStore
    private let configStore: ConfigStore
    private var conversationManager: ConversationManager
    private var cancellables = Set<AnyCancellable>()
    private var useInjectedLLMService: Bool = false

    private var config: AssistantConfig

    init(
        sttService: (any STTServiceProtocol)? = nil,
        speakerService: (any SpeakerServiceProtocol)? = nil,
        llmService: (any LLMServiceProtocol)? = nil,
        configStore: ConfigStore? = nil
    ) {
        let store = configStore ?? ConfigStore()
        self.configStore = store
        self.config = store.loadConfig()

        self.audioEngine = AudioEngine()
        self.vadService = VADService()
        self.audioBuffer = AudioBuffer(maxSeconds: 15)
        self.sttService = sttService ?? STTService()
        self.speakerService = speakerService ?? SpeakerService()

        // Initialize skills
        self.skillsRegistry = SkillsRegistry(config: config.skills)
        self.permissionManager = SkillPermissionManager()

        // Track if LLM service was injected (for testing)
        if let injectedLLM = llmService {
            self.llmService = injectedLLM
            self.useInjectedLLMService = true
        } else {
            self.llmService = LLMService(config: config.llm)
            self.useInjectedLLMService = false
        }


        self.commandProcessor = CommandProcessor(wakePhrase: config.wakePhrase)
        self.speakerStore = SpeakerStore()
        self.conversationManager = ConversationManager(
            timeoutMinutes: config.llm.conversationTimeoutMinutes,
            maxTurns: config.llm.maxConversationTurns
        )

        // Check if onboarding is required
        self.requiresOnboarding = !speakerStore.hasSpeakers()

        setupBindings()
    }

    private func setupBindings() {
        audioEngine.audioChunkPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] chunk in
                Task { [weak self] in
                    await self?.processAudioChunk(chunk)
                }
            }
            .store(in: &cancellables)

        audioEngine.$audioLevel
            .receive(on: DispatchQueue.main)
            .assign(to: &$audioLevel)
    }

    // MARK: - Lifecycle

    func checkOnboardingRequired() -> Bool {
        requiresOnboarding = !speakerStore.hasSpeakers()
        return requiresOnboarding
    }

    func completeOnboarding() {
        requiresOnboarding = false
    }

    func start() async {
        // Don't start if onboarding is required
        guard !requiresOnboarding else {
            print("Cannot start: onboarding required")
            return
        }

        let granted = await Permissions.requestMicrophoneAccess()

        guard granted else {
            state = .error("Microphone access denied")
            return
        }

        isModelLoading = true
        state = .idle

        // Load STT model
        do {
            try await sttService.loadModel()
        } catch {
            isModelLoading = false
            state = .error("Failed to load speech model: \(error.localizedDescription)")
            return
        }

        // Load speaker identification model
        do {
            try await speakerService.loadModel()
        } catch {
            isModelLoading = false
            state = .error("Failed to load speaker model: \(error.localizedDescription)")
            return
        }

        // Check LLM configuration
        llmConfigured = await llmService.isConfigured
        if !llmConfigured {
            print("Warning: LLM is not configured. Commands will not receive AI responses.")
        }

        isModelLoading = false

        audioEngine.start()
        isListening = true
        state = .listening
    }

    func shutdown() {
        audioEngine.stop()
        isListening = false
        state = .idle
        vadService.reset()
        audioBuffer.clear()
        lastTranscription = nil
        lastCommand = nil
        lastResponse = nil
        currentSpeaker = nil
    }

    // MARK: - Configuration

    /// Reload configuration from disk and recreate LLM service
    func reloadConfig() async {
        config = configStore.loadConfig()

        // Recreate LLM service with new config (unless using injected mock)
        if !useInjectedLLMService {
            llmService = LLMService(config: config.llm)
        }

        // Update conversation manager settings
        conversationManager = ConversationManager(
            timeoutMinutes: config.llm.conversationTimeoutMinutes,
            maxTurns: config.llm.maxConversationTurns
        )

        // Update skills configuration
        skillsRegistry.updateConfig(config.skills)

        // Update LLM configured status
        llmConfigured = await llmService.isConfigured
        print("Config reloaded. LLM configured: \(llmConfigured)")
    }

    /// Refresh configuration if it has changed on disk.
    func refreshConfigIfNeeded() async {
        let latest = configStore.loadConfig()
        guard latest != config else {
            return
        }

        config = latest

        if !useInjectedLLMService {
            llmService = LLMService(config: config.llm)
        }

        conversationManager = ConversationManager(
            timeoutMinutes: config.llm.conversationTimeoutMinutes,
            maxTurns: config.llm.maxConversationTurns
        )

        skillsRegistry.updateConfig(config.skills)
        llmConfigured = await llmService.isConfigured
        print("Config refreshed. LLM configured: \(llmConfigured)")
    }

    /// Update skills configuration
    func updateSkillsConfig(_ newConfig: SkillsConfig) {
        skillsRegistry.updateConfig(newConfig)
    }

    /// Clear conversation history (e.g., for "new conversation" command)
    func clearConversation() {
        conversationManager.clearHistory()
    }

    // MARK: - Speaker Management

    func enrollSpeaker(name: String, samples: [AudioChunk]) async throws -> Speaker {
        // Ensure speaker model is loaded (needed for onboarding before start() is called)
        if await !speakerService.isModelLoaded {
            try await speakerService.loadModel()
        }
        
        let speaker = try await speakerService.enroll(name: name, samples: samples)
        enrolledSpeakers = await speakerService.enrolledSpeakers
        requiresOnboarding = false
        return speaker
    }

    func removeSpeaker(_ speaker: Speaker) async {
        do {
            try await speakerService.remove(speaker)
            enrolledSpeakers = await speakerService.enrolledSpeakers
            requiresOnboarding = enrolledSpeakers.isEmpty
        } catch {
            print("Failed to remove speaker: \(error)")
        }
    }

    func getEnrolledSpeakers() async -> [Speaker] {
        await speakerService.enrolledSpeakers
    }
    
    /// Refreshes the enrolled speakers list from the speaker service
    func refreshEnrolledSpeakers() async {
        enrolledSpeakers = await speakerService.enrolledSpeakers
    }

    // MARK: - Audio Processing

    private func processAudioChunk(_ chunk: AudioChunk) async {
        audioBuffer.append(chunk)

        let vadResult = await vadService.processAsync(chunk)

        switch (state, vadResult) {
        case (.listening, .speechStart):
            audioBuffer.markSpeechStart()
            state = .capturing

        case (.capturing, .speechContinue):
            break

        case (.capturing, .speechEnd):
            state = .processing
            let utterance = audioBuffer.getUtteranceSinceSpeechStart()
            await processUtterance(utterance, source: chunk.source)

        default:
            break
        }
    }

    private func processUtterance(_ audio: AudioChunk, source: AudioSource) async {
        print("Processing utterance: \(String(format: "%.2f", audio.duration))s")

        // Run STT and Speaker ID in parallel
        async let transcriptionTask = sttService.transcribe(audio)
        async let speakerTask = speakerService.identify(audio)

        do {
            let (result, speaker) = try await (transcriptionTask, speakerTask)

            // Update UI with transcription and speaker
            lastTranscription = result.text
            currentSpeaker = speaker

            let speakerName = speaker?.name ?? "Guest"
            print("[Coordinator] Setting currentSpeaker to: \(speaker?.name ?? "nil") (ID: \(speaker?.id.uuidString ?? "nil"))")
            print("[\(speakerName)] Transcription: \"\(result.text)\" (confidence: \(String(format: "%.2f", result.confidence)), \(result.processingTimeMs)ms)")

            // Check for wake word and extract command
            if let commandText = commandProcessor.extractCommand(from: result.text) {
                lastCommand = commandText
                print("Wake word detected! Command: \"\(commandText)\"")

                // Process command with LLM
                await processCommand(commandText, speaker: speaker, source: source)
            } else {
                print("No wake word detected in: \"\(result.text)\"")
                // Return to listening state
                state = .listening
            }

        } catch {
            print("Processing error: \(error)")
            lastTranscription = "[Processing failed]"
            state = .listening
        }
    }

    private func processCommand(_ commandText: String, speaker: Speaker?, source: AudioSource) async {
        // Set state to responding
        state = .responding

        // Build command context
        let context = CommandContext(
            command: commandText,
            speaker: speaker,
            source: source,
            conversationHistory: conversationManager.getRecentHistory()
        )

        // Get conversation history for context
        let history = conversationManager.getRecentHistory()

        await refreshConfigIfNeeded()

        // Generate skills manifest for enabled skills
        let skillsManifest = skillsRegistry.generateSkillsManifest()
        let enabledSkillIds = skillsRegistry.enabledSkills.map { $0.id }
        print("[Skills] Enabled skill IDs: \(enabledSkillIds)")

        do {
            let finalResponse = try await completeAndProcessActionPlan(
                prompt: commandText,
                context: context,
                conversationHistory: history,
                skillsManifest: skillsManifest.contains("No skills") ? nil : skillsManifest
            )

            // Update conversation history
            conversationManager.addTurn(role: .user, content: commandText)
            conversationManager.addTurn(role: .assistant, content: finalResponse)

            // Update UI with response
            lastResponse = finalResponse
            print("Response: \(finalResponse)")

            // TODO: Milestone 6 - TTS/Audio response

        } catch let error as LLMError {
            print("LLM Error: \(error.localizedDescription)")
            lastResponse = "[Error: \(error.localizedDescription)]"
        } catch let error as SkillError {
            print("Skill Error: \(error.localizedDescription)")
            lastResponse = "[Error: \(error.localizedDescription)]"
        } catch {
            print("Unexpected error: \(error)")
            lastResponse = "[Error processing command]"
        }

        // Return to listening state
        state = .listening
    }

    // MARK: - Action Plan Processing

    /// Process LLM response as an action plan (JSON) or plain text
    func processActionPlan(from response: String) async throws -> String {
        // Try to parse as JSON action plan
        do {
            let plan = try LLMActionPlan.parse(from: response)
            return try await executeActionPlan(plan)
        } catch {
            // If parsing fails, treat the response as plain text
            // This handles cases where the LLM doesn't return valid JSON
            print("Failed to parse action plan, treating as plain text: \(error)")
            return response
        }
    }

    /// Complete and process an action plan, retrying once if JSON is invalid.
    func completeAndProcessActionPlan(
        prompt: String,
        context: CommandContext?,
        conversationHistory: [ConversationTurn],
        skillsManifest: String?
    ) async throws -> String {
        let llmResponse = try await llmService.complete(
            prompt: prompt,
            context: context,
            conversationHistory: conversationHistory,
            skillsManifest: skillsManifest
        )
        print("[LLM] Raw response: \(llmResponse)")

        do {
            return try await processActionPlanStrict(from: llmResponse)
        } catch {
            guard skillsManifest != nil else {
                print("Failed to parse action plan, treating as plain text: \(error)")
                return llmResponse
            }

            let retryPrompt = buildRetryPrompt(originalPrompt: prompt)
            let retryResponse = try await llmService.complete(
                prompt: retryPrompt,
                context: context,
                conversationHistory: conversationHistory,
                skillsManifest: skillsManifest
            )
            print("[LLM] Retry response: \(retryResponse)")

            do {
                return try await processActionPlanStrict(from: retryResponse)
            } catch {
                print("Failed to parse retry action plan, treating as plain text: \(error)")
                return llmResponse
            }
        }
    }

    private func processActionPlanStrict(from response: String) async throws -> String {
        let plan = try LLMActionPlan.parse(from: response)
        return try await executeActionPlan(plan)
    }

    private func executeActionPlan(_ plan: LLMActionPlan) async throws -> String {
        switch plan {
        case .respond(let text):
            print("[LLM] Action plan: respond")
            return text
        case .callSkills(let calls):
            let callSummary = calls.map { "\($0.skillId)" }.joined(separator: ", ")
            print("[LLM] Action plan: call_skills -> \(callSummary)")
            return try await executeSkillCalls(calls)
        }
    }

    private func buildRetryPrompt(originalPrompt: String) -> String {
        """
        Return ONLY a single JSON action plan for the user request below.
        Do not add any extra text.

        User request: \(originalPrompt)
        """
    }


    /// Execute skill calls from an action plan
    private func executeSkillCalls(_ calls: [SkillCall]) async throws -> String {
        var results: [String] = []

        for call in calls {
            guard let skill = skillsRegistry.skill(withId: call.skillId) else {
                results.append("I couldn't find the skill '\(call.skillId)'.")
                continue
            }

            guard skillsRegistry.isSkillEnabled(call.skillId) else {
                results.append("The \(skill.name) skill is currently disabled. You can enable it in Settings.")
                continue
            }

            // Check permissions
            let hasPermissions = await permissionManager.hasAllPermissions(for: skill)
            if !hasPermissions {
                let missing = await permissionManager.missingPermissions(for: skill)
                let missingNames = missing.map { $0.displayName }.joined(separator: ", ")
                results.append("The \(skill.name) skill requires \(missingNames) permission. Please grant access in System Settings.")
                continue
            }

            // Execute the skill
            do {
                let argsJSON = try call.argumentsAsJSON()
                let context = SkillContext(
                    speaker: currentSpeaker,
                    source: .localMic
                )
                let result = try await skill.run(argumentsJSON: argsJSON, context: context)
                results.append(result.text)
            } catch let error as SkillError {
                results.append("Error with \(skill.name): \(error.localizedDescription)")
            } catch {
                results.append("An error occurred while running \(skill.name).")
            }
        }

        return results.joined(separator: " ")
    }
}
