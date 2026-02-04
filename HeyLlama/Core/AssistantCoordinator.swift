import Foundation
import Combine

@MainActor
final class AssistantCoordinator: ObservableObject {
    @Published private(set) var state: AssistantState = .idle
    @Published private(set) var isListening: Bool = false
    @Published private(set) var isListeningPaused: Bool = false
    @Published private(set) var audioLevel: Float = 0
    @Published private(set) var lastTranscription: String?
    @Published private(set) var lastCommand: String?
    @Published private(set) var lastResponse: String?
    @Published private(set) var isModelLoading: Bool = false
    @Published private(set) var currentSpeaker: Speaker?
    @Published private(set) var requiresOnboarding: Bool = true
    @Published private(set) var enrolledSpeakers: [Speaker] = []
    @Published private(set) var llmConfigured: Bool = false
    @Published private(set) var musicPermissionStatus: Permissions.PermissionStatus = Permissions.checkMusicStatus()
    @Published private(set) var isMusicSkillEnabled: Bool = false

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
    private let musicPlaybackController: MusicPlaybackController

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


        self.commandProcessor = CommandProcessor(
            wakePhrase: config.wakePhrase,
            closingPhrases: config.llm.conversationClosingPhrases
        )
        self.speakerStore = SpeakerStore()
        self.conversationManager = ConversationManager(
            timeoutMinutes: config.llm.conversationTimeoutMinutes,
            maxTurns: config.llm.maxConversationTurns,
            followUpWindowSeconds: config.llm.followUpWindowSeconds
        )

        // Check if onboarding is required
        self.requiresOnboarding = !speakerStore.hasSpeakers()
        self.musicPlaybackController = MusicPlaybackController.shared

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

        await runStartupPreflight()

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
        isListeningPaused = false
        state = .listening
    }

    private func runStartupPreflight() async {
        print("[Startup] LLM provider: \(config.llm.provider.rawValue)")

        let enabledSkills = skillsRegistry.enabledSkills
        let enabledSkillIds = enabledSkills.map { $0.id }
        print("[Startup] Enabled skills: \(enabledSkillIds)")
        updateMusicSkillEnabled()

        for skill in enabledSkills {
            let requiredPermissions = skill.requiredPermissions
            let permissionNames = requiredPermissions.map { $0.displayName }

            if permissionNames.isEmpty {
                print("[Startup] Skill \(skill.id) requires no permissions")
                continue
            }

            print("[Startup] Skill \(skill.id) required permissions: \(permissionNames)")

            for permission in requiredPermissions {
                let status = await permissionManager.checkPermissionStatus(permission)
                print("[Startup] Permission \(permission.rawValue) status: \(status)")
                if permission == .music {
                    musicPermissionStatus = status
                }

                if status == .undetermined {
                    let granted = await permissionManager.requestPermission(permission)
                    print("[Startup] Permission \(permission.rawValue) request result: \(granted)")
                    if permission == .music {
                        musicPermissionStatus = granted ? .granted : .denied
                    }
                }
            }
        }
    }

    func shutdown() {
        audioEngine.stop()
        isListening = false
        isListeningPaused = false
        state = .idle
        vadService.reset()
        audioBuffer.clear()
        lastTranscription = nil
        lastCommand = nil
        lastResponse = nil
        currentSpeaker = nil
        conversationManager.endFollowUpWindow()
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
            maxTurns: config.llm.maxConversationTurns,
            followUpWindowSeconds: config.llm.followUpWindowSeconds
        )

        // Update skills configuration
        skillsRegistry.updateConfig(config.skills)
        updateMusicSkillEnabled()

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
            maxTurns: config.llm.maxConversationTurns,
            followUpWindowSeconds: config.llm.followUpWindowSeconds
        )

        skillsRegistry.updateConfig(config.skills)
        updateMusicSkillEnabled()
        llmConfigured = await llmService.isConfigured
        print("Config refreshed. LLM configured: \(llmConfigured)")
    }

    /// Update skills configuration
    func updateSkillsConfig(_ newConfig: SkillsConfig) {
        skillsRegistry.updateConfig(newConfig)
        updateMusicSkillEnabled()
    }

    // MARK: - Listening Control

    func pauseListening(reason: ListeningPauseReason) {
        guard !isListeningPaused else { return }
        audioEngine.stop()
        isListening = false
        isListeningPaused = true
        state = .pausedListening
        print("[Listening] Paused (\(reason.rawValue))")
    }

    func resumeListening(reason: ListeningPauseReason) {
        guard isListeningPaused else { return }
        audioEngine.start()
        isListening = true
        isListeningPaused = false
        state = .listening
        print("[Listening] Resumed (\(reason.rawValue))")
    }

    /// Clear conversation history (e.g., for "new conversation" command)
    func clearConversation() {
        conversationManager.clearHistory()
        conversationManager.endFollowUpWindow()
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
        let isFollowUpActive = conversationManager.isFollowUpActive()
        async let transcriptionTask = sttService.transcribe(audio)
        async let speakerTask = speakerService.identify(
            audio,
            thresholdOverride: isFollowUpActive ? 0.8 : nil
        )

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
                // TODO: Consider LLM-assisted end-of-conversation detection.
                if commandProcessor.isClosingPhrase(commandText) {
                    print("Closing phrase detected after wake word. Ending conversation window.")
                    conversationManager.endFollowUpWindow()
                    state = .listening
                    return
                }

                lastCommand = commandText
                print("Wake word detected! Command: \"\(commandText)\"")

                // Process command with LLM
                await processCommand(commandText, speaker: speaker, source: source)
                return
            }

            // Follow-up flow (no wake word)
            if conversationManager.isFollowUpActive() {
                let trimmedText = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmedText.isEmpty {
                    state = .listening
                    return
                }

                // TODO: Consider LLM-assisted end-of-conversation detection.
                if commandProcessor.isClosingPhrase(trimmedText) {
                    print("Closing phrase detected in follow-up. Ending conversation window.")
                    conversationManager.endFollowUpWindow()
                    state = .listening
                    return
                }

                guard let enrolledSpeaker = speaker else {
                    lastResponse = "Sorry, I missed that. Please repeat."
                    print("Follow-up detected but speaker not identified. Asking to repeat.")
                    conversationManager.extendFollowUpWindow()
                    state = .listening
                    return
                }

                lastCommand = trimmedText
                print("Follow-up detected from \(enrolledSpeaker.name). Command: \"\(trimmedText)\"")

                await processCommand(trimmedText, speaker: enrolledSpeaker, source: source)
                return
            }

            print("No wake word detected in: \"\(result.text)\"")
            // Return to listening state
            state = .listening

        } catch {
            print("Processing error: \(error)")
            lastTranscription = "[Processing failed]"
            state = .listening
        }
    }

    private func processCommand(_ commandText: String, speaker: Speaker?, source: AudioSource) async {
        // Set state to responding
        state = .responding

        // Handle yes/no/cancel confirmations before invoking the LLM.
        if let confirmation = conversationManager.getPendingConfirmation() {
            switch classifyConfirmationReply(commandText) {
            case .confirm:
                conversationManager.clearPendingConfirmation()
                do {
                    let call = SkillCall(
                        skillId: confirmation.skillId,
                        arguments: confirmation.arguments
                    )
                    let response = try await executeSkillCalls(
                        [call],
                        userRequest: confirmation.originUserRequest
                    )
                    conversationManager.addTurn(role: .user, content: commandText)
                    conversationManager.addTurn(role: .assistant, content: response)
                    lastResponse = response
                    state = .listening
                    return
                } catch {
                    print("Error executing confirmed skill: \(error)")
                    lastResponse = "[Error processing confirmation]"
                    state = .listening
                    return
                }

            case .deny:
                conversationManager.clearPendingConfirmation()
                let response = "Okay, I won't do that."
                conversationManager.addTurn(role: .user, content: commandText)
                conversationManager.addTurn(role: .assistant, content: response)
                lastResponse = response
                state = .listening
                return

            case .cancel:
                conversationManager.clearPendingConfirmation()
                let response = "Okay, cancelled."
                conversationManager.addTurn(role: .user, content: commandText)
                conversationManager.addTurn(role: .assistant, content: response)
                lastResponse = response
                state = .listening
                return

            case .unknown:
                print("[Confirm] Pending confirmation still active; deferring to LLM.")
                break
            }
        }

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

        // Reset follow-up window after a successful command cycle
        conversationManager.extendFollowUpWindow()

        // Return to listening state
        state = .listening
    }

    // MARK: - Action Plan Processing

    /// Process LLM response as an action plan (JSON) or plain text
    func processActionPlan(from response: String, userRequest: String? = nil) async throws -> String {
        // Try to parse as JSON action plan
        do {
            let plan = try LLMActionPlan.parse(from: response)
            return try await executeActionPlan(plan, userRequest: userRequest)
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
            return try await processActionPlanStrict(from: llmResponse, userRequest: prompt)
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
                return try await processActionPlanStrict(from: retryResponse, userRequest: prompt)
            } catch {
                print("Failed to parse retry action plan, treating as plain text: \(error)")
                return llmResponse
            }
        }
    }

    private func processActionPlanStrict(from response: String, userRequest: String? = nil) async throws -> String {
        let plan = try LLMActionPlan.parse(from: response)
        return try await executeActionPlan(plan, userRequest: userRequest)
    }

    private func executeActionPlan(_ plan: LLMActionPlan, userRequest: String? = nil) async throws -> String {
        switch plan {
        case .respond(let text):
            print("[LLM] Action plan: respond")
            return text
        case .callSkills(let calls):
            let callSummary = calls.map { "\($0.skillId)" }.joined(separator: ", ")
            print("[LLM] Action plan: call_skills -> \(callSummary)")
            return try await executeSkillCalls(calls, userRequest: userRequest)
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
    private func executeSkillCalls(_ calls: [SkillCall], userRequest: String? = nil) async throws -> String {
        let sanitizedCalls = sanitizeWeatherCalls(calls, userRequest: userRequest)
        let filteredCalls = filterReminderCalls(sanitizedCalls, userRequest: userRequest)
        var results: [String] = []
        var summaries: [SkillSummary] = []

        for call in filteredCalls {
            // Use new Skill type API
            guard let skillType = SkillsRegistry.skillType(withId: call.skillId) else {
                // Don't add to summaries - skill doesn't exist
                results.append("I couldn't find the skill '\(call.skillId)'.")
                continue
            }

            guard skillsRegistry.isSkillEnabled(call.skillId) else {
                // Don't add to summaries - skill is disabled
                results.append("The \(skillType.name) skill is currently disabled. You can enable it in Settings.")
                continue
            }

            // Check permissions using new skill type API
            let missing = await permissionManager.missingPermissions(forSkillType: skillType)
            if !missing.isEmpty {
                let missingNames = missing.map { $0.displayName }.joined(separator: ", ")
                let message = "The \(skillType.name) skill requires \(missingNames) permission. Please grant access in System Settings."
                results.append(message)
                // Add to summaries for permission errors since skill would run if permitted
                if skillType.includesInResponseAgent {
                    summaries.append(SkillSummary(
                        skillId: call.skillId,
                        status: .failed,
                        summary: message
                    ))
                }
                continue
            }

            // Execute the skill using the registry's executeSkill method
            do {
                let argsJSON = try call.argumentsAsJSON()
                print("[Skill] Executing \(call.skillId) with arguments: \(argsJSON)")

                let context = SkillContext(
                    speaker: currentSpeaker,
                    source: .localMic
                )
                let result = try await skillsRegistry.executeSkill(
                    skillId: call.skillId,
                    argumentsJSON: argsJSON,
                    context: context
                )
                print("[Skill] \(call.skillId) result text: \(result.text)")
                if let data = result.data {
                    print("[Skill] \(call.skillId) result data: \(data)")
                }
                if let data = result.data,
                   let listeningAction = data["listeningAction"] as? String {
                    handleListeningAction(listeningAction)
                }
                if let data = result.data {
                    let pending = PendingConfirmation.fromSkillResultData(
                        data,
                        defaultExpiry: conversationManager.pendingConfirmationExpiryDate(),
                        originUserRequest: userRequest
                    )
                    if let pending = pending {
                        conversationManager.setPendingConfirmation(pending)
                        return pending.prompt
                    }
                }
                results.append(result.text)

                // Use skill's summary if available, otherwise create one
                if let summary = result.summary, skillType.includesInResponseAgent {
                    print("[Skill] \(call.skillId) summary: \(summary.summary)")
                    summaries.append(summary)
                } else if skillType.includesInResponseAgent {
                    print("[Skill] \(call.skillId) creating summary from result text")
                    summaries.append(SkillSummary(
                        skillId: call.skillId,
                        status: .success,
                        summary: result.text
                    ))
                }
            } catch let error as SkillError {
                let message = "Error with \(skillType.name): \(error.localizedDescription)"
                results.append(message)
                if skillType.includesInResponseAgent {
                    summaries.append(SkillSummary(
                        skillId: call.skillId,
                        status: .failed,
                        summary: message
                    ))
                }
            } catch {
                let message = "An error occurred while running \(skillType.name)."
                results.append(message)
                if skillType.includesInResponseAgent {
                    summaries.append(SkillSummary(
                        skillId: call.skillId,
                        status: .failed,
                        summary: message
                    ))
                }
            }
        }

        // If we have summaries and a user request, use ResponseAgent
        if !summaries.isEmpty {
            print("[ResponseAgent] Invoking with \(summaries.count) summaries:")
            for summary in summaries {
                print("[ResponseAgent]   - \(summary.skillId): \(summary.status) - \(summary.summary.prefix(100))...")
            }

            do {
                let speakerName = currentSpeaker?.name
                let response = try await ResponseAgent.generateResponse(
                    userRequest: userRequest ?? "User request",
                    speakerName: speakerName,
                    summaries: summaries,
                    llmService: llmService
                )
                return response
            } catch {
                // Fallback to deterministic concatenation if ResponseAgent fails
                print("ResponseAgent failed, using fallback: \(error)")
                return results.joined(separator: " ")
            }
        }

        return results.joined(separator: " ")
    }

    // MARK: - Helpers

    private func updateMusicSkillEnabled() {
        let ids = [
            AppleMusicPlaySkill.id,
            AppleMusicAddToPlaylistSkill.id,
            AppleMusicNowPlayingSkill.id,
            AppleMusicControlSkill.id
        ]
        isMusicSkillEnabled = ids.contains { skillsRegistry.isSkillEnabled($0) }
    }

    private func handleListeningAction(_ action: String) {
        switch action.lowercased() {
        case "pause":
            pauseListening(reason: .autoPlayback)
        case "resume":
            resumeListening(reason: .autoPlayback)
        default:
            break
        }
    }

    // MARK: - Call Sanitization

    private func sanitizeWeatherCalls(_ calls: [SkillCall], userRequest: String?) -> [SkillCall] {
        guard let userRequest = userRequest else {
            return calls
        }

        let normalizedRequest = normalizeText(userRequest)
        guard requestUsesImplicitLocation(normalizedRequest) else {
            return calls
        }

        return calls.map { call in
            guard call.skillId == WeatherForecastSkill.id,
                  let location = call.arguments["location"] as? String,
                  !location.isEmpty
            else {
                return call
            }

            if isLocationExplicit(location, in: normalizedRequest) {
                return call
            }

            var updatedArguments = call.arguments
            updatedArguments.removeValue(forKey: "location")
            return SkillCall(skillId: call.skillId, arguments: updatedArguments)
        }
    }

    private func requestUsesImplicitLocation(_ normalizedRequest: String) -> Bool {
        let phrases = [
            "my weather",
            "my location",
            "where i am",
            "where im",
            "where i'm",
            "here",
            "my area",
            "local weather",
            "where i live"
        ]
        return phrases.contains { normalizedRequest.contains($0) }
    }

    private func isLocationExplicit(_ location: String, in normalizedRequest: String) -> Bool {
        let locationTokens = normalizeText(location)
            .split(separator: " ")
            .map(String.init)
        guard !locationTokens.isEmpty else {
            return false
        }
        return locationTokens.allSatisfy { normalizedRequest.contains($0) }
    }

    private func normalizeText(_ text: String) -> String {
        let lowered = text.lowercased()
        let replaced = lowered.replacingOccurrences(
            of: "[^a-z0-9\\s]",
            with: " ",
            options: .regularExpression
        )
        let collapsed = replaced.replacingOccurrences(
            of: "\\s+",
            with: " ",
            options: .regularExpression
        )
        return collapsed.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Confirmation Handling

    private enum ConfirmationReply {
        case confirm
        case deny
        case cancel
        case unknown
    }

    private func classifyConfirmationReply(_ text: String) -> ConfirmationReply {
        let normalized = normalizeConfirmationText(text)
        guard !normalized.isEmpty else {
            return .unknown
        }

        let tokens = normalized.split(separator: " ").map(String.init)
        if tokens.isEmpty {
            return .unknown
        }

        let cancelPhrases: Set<[String]> = [
            ["cancel"],
            ["never", "mind"],
            ["nevermind"]
        ]
        if matchesAnyPhrase(tokens, phrases: cancelPhrases) {
            return .cancel
        }

        let yesPhrases: Set<[String]> = [
            ["yes"],
            ["yeah"],
            ["yep"],
            ["sure"],
            ["ok"],
            ["okay"],
            ["do", "it"],
            ["please", "do"],
            ["go", "ahead"]
        ]

        let noPhrases: Set<[String]> = [
            ["no"],
            ["nope"],
            ["nah"],
            ["dont"],
            ["do", "not"]
        ]

        if matchesAnyPhrase(tokens, phrases: yesPhrases) {
            return .confirm
        }

        if matchesAnyPhrase(tokens, phrases: noPhrases) {
            return .deny
        }

        return .unknown
    }

    private func normalizeConfirmationText(_ text: String) -> String {
        let lowered = text.lowercased()
        let allowed = CharacterSet.alphanumerics.union(.whitespaces)
        let filtered = lowered.unicodeScalars.filter { allowed.contains($0) }
        let collapsed = String(filtered)
            .split(separator: " ")
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let ignoreTokens = Set(["please", "thanks", "thank", "you"])
        let tokens = collapsed.split(separator: " ").map(String.init)
        let filteredTokens = tokens.filter { !ignoreTokens.contains($0) }
        return filteredTokens.joined(separator: " ")
    }

    private func matchesAnyPhrase(_ tokens: [String], phrases: Set<[String]>) -> Bool {
        for phrase in phrases where tokens == phrase {
            return true
        }
        return false
    }

    private func filterReminderCalls(_ calls: [SkillCall], userRequest: String?) -> [SkillCall] {
        guard let userRequest = userRequest else {
            return dedupeCalls(calls)
        }

        if conversationManager.isFollowUpActive() || conversationManager.getPendingConfirmation() != nil {
            return dedupeCalls(calls)
        }

        let normalizedRequest = normalizeText(userRequest)
        var filtered: [SkillCall] = []

        for call in calls {
            guard call.skillId == RemindersAddItemSkill.id else {
                filtered.append(call)
                continue
            }

            guard let itemName = call.arguments["itemName"] as? String else {
                filtered.append(call)
                continue
            }

            let itemTokens = normalizeText(itemName).split(separator: " ").map(String.init)
            if itemTokens.isEmpty || itemTokens.allSatisfy({ normalizedRequest.contains($0) }) {
                filtered.append(call)
            } else {
                print("[Skill] Skipping reminders.add_item call for item '\(itemName)' not referenced in request.")
            }
        }

        return dedupeCalls(filtered)
    }

    private func dedupeCalls(_ calls: [SkillCall]) -> [SkillCall] {
        var seen = Set<String>()
        var result: [SkillCall] = []

        for call in calls {
            let argsKey: String
            if let data = try? JSONSerialization.data(withJSONObject: call.arguments, options: [.sortedKeys]),
               let json = String(data: data, encoding: .utf8) {
                argsKey = json
            } else {
                argsKey = String(describing: call.arguments)
            }
            let key = "\(call.skillId)|\(argsKey)"
            if seen.contains(key) {
                continue
            }
            seen.insert(key)
            result.append(call)
        }

        return result
    }
}

enum ListeningPauseReason: String {
    case manual
    case autoPlayback
}
