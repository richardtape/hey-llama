import Foundation
import Combine

/// Handles audio recording for speaker enrollment with VAD-based speech detection
@MainActor
final class EnrollmentRecorder: ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var audioLevel: Float = 0
    @Published private(set) var hasMicrophonePermission = false
    @Published private(set) var errorMessage: String?
    
    private var audioEngine: AudioEngine?
    private var vadService: VADService?
    private var audioBuffer: AudioBuffer?
    private var cancellables = Set<AnyCancellable>()
    
    private var isSpeechActive = false
    private var onSampleRecorded: ((AudioChunk) -> Void)?
    
    init() {}
    
    /// Request microphone permission and prepare for recording
    func prepare() async -> Bool {
        let granted = await Permissions.requestMicrophoneAccess()
        hasMicrophonePermission = granted
        
        if !granted {
            errorMessage = "Microphone access is required for voice enrollment"
            return false
        }
        
        // Initialize audio components
        audioEngine = AudioEngine()
        vadService = VADService()
        audioBuffer = AudioBuffer(maxSeconds: 10)
        
        setupBindings()
        return true
    }
    
    private func setupBindings() {
        guard let audioEngine = audioEngine else { return }
        
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
    
    /// Start recording with callback when a complete utterance is captured
    func startRecording(onSampleRecorded: @escaping (AudioChunk) -> Void) {
        guard let audioEngine = audioEngine else {
            errorMessage = "Audio engine not initialized. Call prepare() first."
            return
        }
        
        self.onSampleRecorded = onSampleRecorded
        audioBuffer?.clear()
        vadService?.reset()
        isSpeechActive = false
        
        audioEngine.start()
        isRecording = true
        errorMessage = nil
    }
    
    /// Stop recording and return any captured audio
    func stopRecording() -> AudioChunk? {
        guard isRecording else { return nil }
        
        audioEngine?.stop()
        isRecording = false
        
        // If we have speech in the buffer, return it
        if isSpeechActive, let buffer = audioBuffer {
            let utterance = buffer.getUtteranceSinceSpeechStart()
            if utterance.duration > 0.5 {
                return utterance
            }
        }
        
        return nil
    }
    
    /// Clean up resources
    func cleanup() {
        audioEngine?.stop()
        audioEngine = nil
        vadService = nil
        audioBuffer = nil
        cancellables.removeAll()
        isRecording = false
    }
    
    private func processAudioChunk(_ chunk: AudioChunk) async {
        guard isRecording, let vadService = vadService, let audioBuffer = audioBuffer else {
            return
        }
        
        audioBuffer.append(chunk)
        
        let vadResult = await vadService.processAsync(chunk)
        
        switch vadResult {
        case .speechStart:
            audioBuffer.markSpeechStart()
            isSpeechActive = true
            
        case .speechContinue:
            break
            
        case .speechEnd:
            if isSpeechActive {
                let utterance = audioBuffer.getUtteranceSinceSpeechStart()
                
                // Only accept utterances longer than 0.5 seconds
                if utterance.duration > 0.5 {
                    onSampleRecorded?(utterance)
                }
                
                // Reset for next phrase
                audioBuffer.clear()
                vadService.reset()
                isSpeechActive = false
            }
            
        case .silence:
            break
        }
    }
}
