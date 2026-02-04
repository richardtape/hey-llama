import Foundation

enum SpeakerServiceError: Error, LocalizedError {
    case modelNotLoaded
    case insufficientSamples(required: Int, provided: Int)
    case embeddingExtractionFailed(String)
    case speakerNotFound

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "Speaker identification model is not loaded"
        case .insufficientSamples(let required, let provided):
            return "Insufficient audio samples: need \(required), got \(provided)"
        case .embeddingExtractionFailed(let reason):
            return "Failed to extract voice embedding: \(reason)"
        case .speakerNotFound:
            return "Speaker not found"
        }
    }
}

protocol SpeakerServiceProtocol: Sendable {
    var isModelLoaded: Bool { get async }
    var enrolledSpeakers: [Speaker] { get async }

    func loadModel() async throws
    func identify(_ audio: AudioChunk, thresholdOverride: Float?) async -> Speaker?
    func enroll(name: String, samples: [AudioChunk]) async throws -> Speaker
    func remove(_ speaker: Speaker) async throws
    func updateSpeaker(_ speaker: Speaker) async throws
}

extension SpeakerServiceProtocol {
    func identify(_ audio: AudioChunk) async -> Speaker? {
        await identify(audio, thresholdOverride: nil)
    }
}
