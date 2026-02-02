import Foundation
import Combine

@MainActor
final class AssistantCoordinator: ObservableObject {
    @Published private(set) var state: AssistantState = .idle
    @Published private(set) var isListening: Bool = false
    @Published private(set) var audioLevel: Float = 0
    @Published private(set) var lastTranscription: String?
    @Published private(set) var lastCommand: String?
    @Published private(set) var isModelLoading: Bool = false
    @Published private(set) var currentSpeaker: Speaker?
    @Published private(set) var requiresOnboarding: Bool = true

    private let audioEngine: AudioEngine
    private let vadService: VADService
    private let audioBuffer: AudioBuffer
    private let sttService: any STTServiceProtocol
    private let speakerService: any SpeakerServiceProtocol
    private let commandProcessor: CommandProcessor
    private let speakerStore: SpeakerStore
    private var cancellables = Set<AnyCancellable>()

    init(
        sttService: (any STTServiceProtocol)? = nil,
        speakerService: (any SpeakerServiceProtocol)? = nil
    ) {
        self.audioEngine = AudioEngine()
        self.vadService = VADService()
        self.audioBuffer = AudioBuffer(maxSeconds: 15)
        self.sttService = sttService ?? STTService()
        self.speakerService = speakerService ?? SpeakerService()
        self.commandProcessor = CommandProcessor()
        self.speakerStore = SpeakerStore()

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
        currentSpeaker = nil
    }

    // MARK: - Speaker Management

    func enrollSpeaker(name: String, samples: [AudioChunk]) async throws -> Speaker {
        // Ensure speaker model is loaded (needed for onboarding before start() is called)
        if await !speakerService.isModelLoaded {
            try await speakerService.loadModel()
        }
        
        let speaker = try await speakerService.enroll(name: name, samples: samples)
        requiresOnboarding = false
        return speaker
    }

    func removeSpeaker(_ speaker: Speaker) async {
        do {
            try await speakerService.remove(speaker)
            // Check if we need onboarding again
            let speakers = await speakerService.enrolledSpeakers
            requiresOnboarding = speakers.isEmpty
        } catch {
            print("Failed to remove speaker: \(error)")
        }
    }

    func getEnrolledSpeakers() async -> [Speaker] {
        await speakerService.enrolledSpeakers
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
            print("[\(speakerName)] Transcription: \"\(result.text)\" (confidence: \(String(format: "%.2f", result.confidence)), \(result.processingTimeMs)ms)")

            // Check for wake word and extract command
            if let commandText = commandProcessor.extractCommand(from: result.text) {
                lastCommand = commandText
                print("Wake word detected! Command: \"\(commandText)\"")

                // Create command object for future LLM integration (Milestone 4)
                let command = Command(
                    rawText: result.text,
                    commandText: commandText,
                    speaker: speaker,
                    source: source,
                    confidence: result.confidence
                )

                // TODO: In Milestone 4, send command to LLM
                _ = command
            } else {
                print("No wake word detected in: \"\(result.text)\"")
            }

        } catch {
            print("Processing error: \(error)")
            lastTranscription = "[Processing failed]"
        }

        // Return to listening
        state = .listening
    }
}
