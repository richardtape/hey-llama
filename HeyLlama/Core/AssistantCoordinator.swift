import Foundation
import Combine

@MainActor
final class AssistantCoordinator: ObservableObject {
    @Published private(set) var state: AssistantState = .idle
    @Published private(set) var isListening: Bool = false
    @Published private(set) var audioLevel: Float = 0

    private let audioEngine: AudioEngine
    private let vadService: VADService
    private let audioBuffer: AudioBuffer
    private var cancellables = Set<AnyCancellable>()

    init() {
        self.audioEngine = AudioEngine()
        self.vadService = VADService()
        self.audioBuffer = AudioBuffer(maxSeconds: 15)

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

            // Log utterance duration for debugging
            print("Captured utterance: \(String(format: "%.2f", utterance.duration))s")

            // Placeholder: In Milestone 2, we'll send to STT
            // For now, return to listening after brief delay
            Task {
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
                state = .listening
            }

        default:
            break
        }
    }
}
