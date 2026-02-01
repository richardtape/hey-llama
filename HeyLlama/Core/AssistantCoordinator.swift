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

    private let audioEngine: AudioEngine
    private let vadService: VADService
    private let audioBuffer: AudioBuffer
    private let sttService: any STTServiceProtocol
    private let commandProcessor: CommandProcessor
    private var cancellables = Set<AnyCancellable>()

    init(sttService: (any STTServiceProtocol)? = nil) {
        self.audioEngine = AudioEngine()
        self.vadService = VADService()
        self.audioBuffer = AudioBuffer(maxSeconds: 15)
        self.sttService = sttService ?? STTService()
        self.commandProcessor = CommandProcessor()

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

    func start() async {
        let granted = await Permissions.requestMicrophoneAccess()

        guard granted else {
            state = .error("Microphone access denied")
            return
        }

        // Load STT model before starting audio
        isModelLoading = true
        state = .idle

        do {
            try await sttService.loadModel()
            isModelLoading = false
        } catch {
            isModelLoading = false
            state = .error("Failed to load speech model: \(error.localizedDescription)")
            return
        }

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
    }

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

        do {
            let result = try await sttService.transcribe(audio)

            // Update UI with transcription
            lastTranscription = result.text

            print("Transcription: \"\(result.text)\" (confidence: \(String(format: "%.2f", result.confidence)), \(result.processingTimeMs)ms)")

            // Check for wake word and extract command
            if let commandText = commandProcessor.extractCommand(from: result.text) {
                lastCommand = commandText
                print("Wake word detected! Command: \"\(commandText)\"")

                // Create command object for future LLM integration (Milestone 4)
                let command = Command(
                    rawText: result.text,
                    commandText: commandText,
                    source: source,
                    confidence: result.confidence
                )

                // TODO: In Milestone 4, send command to LLM
                _ = command
            } else {
                print("No wake word detected in: \"\(result.text)\"")
            }

        } catch {
            print("Transcription error: \(error)")
            lastTranscription = "[Transcription failed]"
        }

        // Return to listening
        state = .listening
    }
}
