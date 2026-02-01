import Foundation
import WhisperKit

enum STTError: Error, LocalizedError {
    case modelNotLoaded
    case transcriptionFailed(String)
    case invalidAudioFormat

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "WhisperKit model is not loaded"
        case .transcriptionFailed(let reason):
            return "Transcription failed: \(reason)"
        case .invalidAudioFormat:
            return "Invalid audio format for transcription"
        }
    }
}

actor STTService: STTServiceProtocol {
    private var whisperKit: WhisperKit?
    private let modelName: String

    var isModelLoaded: Bool {
        whisperKit != nil
    }

    init(modelName: String = "base") {
        self.modelName = modelName
    }

    func loadModel() async throws {
        let startTime = Date()

        do {
            whisperKit = try await WhisperKit(model: modelName)

            let loadTime = Date().timeIntervalSince(startTime)
            print("WhisperKit model '\(modelName)' loaded in \(String(format: "%.2f", loadTime))s")
        } catch {
            print("Failed to load WhisperKit model: \(error)")
            throw error
        }
    }

    func transcribe(_ audio: AudioChunk) async throws -> TranscriptionResult {
        guard let whisperKit = whisperKit else {
            throw STTError.modelNotLoaded
        }

        guard !audio.samples.isEmpty else {
            throw STTError.invalidAudioFormat
        }

        let startTime = Date()

        do {
            let results = try await whisperKit.transcribe(audioArray: audio.samples)

            let processingTimeMs = Int(Date().timeIntervalSince(startTime) * 1000)

            guard let result = results.first else {
                return TranscriptionResult(
                    text: "",
                    confidence: 0,
                    language: "en",
                    processingTimeMs: processingTimeMs
                )
            }

            // Extract word timings if available
            let wordTimings: [WordTiming]? = result.segments.flatMap { segment in
                segment.words?.map { word in
                    WordTiming(
                        word: word.word,
                        startTime: TimeInterval(word.start),
                        endTime: TimeInterval(word.end),
                        confidence: word.probability
                    )
                } ?? []
            }

            // Calculate average confidence from segments
            let totalConfidence = result.segments.reduce(Float(0)) { sum, segment in
                sum + segment.avgLogprob
            }
            let avgConfidence = result.segments.isEmpty ? 0 : exp(totalConfidence / Float(result.segments.count))

            return TranscriptionResult(
                text: result.text.trimmingCharacters(in: .whitespacesAndNewlines),
                confidence: avgConfidence,
                language: result.language,
                processingTimeMs: processingTimeMs,
                words: wordTimings?.isEmpty == false ? wordTimings : nil
            )
        } catch {
            throw STTError.transcriptionFailed(error.localizedDescription)
        }
    }
}
