import Foundation

/// Protocol for VAD processor to enable testing
protocol VADProcessorProtocol {
    func process(_ samples: [Float]) async -> Float
}

#if canImport(FluidAudio)
import FluidAudio

/// Wrapper around FluidAudio's VadManager
final class FluidVADProcessor: VADProcessorProtocol {
    private var manager: VadManager?
    private var streamState: VadStreamState?
    private let config: VadConfig

    init(config: VadConfig = .default) {
        self.config = config
    }

    private func ensureInitialized() async throws {
        if manager == nil {
            manager = try await VadManager(config: config)
            streamState = await manager?.makeStreamState()
        }
    }

    func process(_ samples: [Float]) async -> Float {
        do {
            try await ensureInitialized()
            guard let manager = manager, let state = streamState else {
                return 0.0
            }

            let result = try await manager.processStreamingChunk(
                samples,
                state: state,
                config: .default
            )
            streamState = result.state
            return result.probability
        } catch {
            print("VAD processing error: \(error)")
            return 0.0
        }
    }
}
#else
/// Stub processor when FluidAudio is not available
final class FluidVADProcessor: VADProcessorProtocol {
    func process(_ samples: [Float]) async -> Float {
        return 0.0
    }
}
#endif

enum VADResult: Equatable {
    case silence
    case speechStart
    case speechContinue
    case speechEnd
}

final class VADService {
    private let vadProcessor: VADProcessorProtocol
    private var speechActive = false
    private var silenceFrames = 0
    private let silenceThreshold = 10 // ~300ms at 30ms per frame
    private let probabilityThreshold: Float = 0.5

    // Buffer for accumulating samples (VadManager expects ~256ms chunks)
    private var sampleBuffer: [Float] = []
    private let targetChunkSize: Int
    private var lastProbability: Float = 0.0

    /// Initialize VADService
    /// - Parameters:
    ///   - vadProcessor: VAD processor (defaults to FluidVADProcessor)
    ///   - targetChunkSize: Samples needed before processing (4096 for production, smaller for tests)
    init(vadProcessor: VADProcessorProtocol? = nil, targetChunkSize: Int = 4096) {
        self.vadProcessor = vadProcessor ?? FluidVADProcessor()
        self.targetChunkSize = targetChunkSize
    }

    func process(_ chunk: AudioChunk) -> VADResult {
        // For synchronous callers using mock processor in tests
        // Real usage should call processAsync
        let probability = lastProbability
        return evaluateProbability(probability)
    }

    func processAsync(_ chunk: AudioChunk) async -> VADResult {
        // Accumulate samples
        sampleBuffer.append(contentsOf: chunk.samples)

        // Process when we have enough samples
        if sampleBuffer.count >= targetChunkSize {
            let samplesToProcess = Array(sampleBuffer.prefix(targetChunkSize))
            sampleBuffer.removeFirst(targetChunkSize)

            lastProbability = await vadProcessor.process(samplesToProcess)
        }

        return evaluateProbability(lastProbability)
    }

    private func evaluateProbability(_ probability: Float) -> VADResult {
        let isSpeech = probability > probabilityThreshold

        if isSpeech {
            silenceFrames = 0

            if !speechActive {
                speechActive = true
                return .speechStart
            } else {
                return .speechContinue
            }
        } else {
            if speechActive {
                silenceFrames += 1

                if silenceFrames >= silenceThreshold {
                    speechActive = false
                    silenceFrames = 0
                    return .speechEnd
                } else {
                    return .speechContinue
                }
            } else {
                return .silence
            }
        }
    }

    func reset() {
        speechActive = false
        silenceFrames = 0
        sampleBuffer.removeAll()
        lastProbability = 0.0
    }
}
