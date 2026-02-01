import Foundation

protocol STTServiceProtocol: Sendable {
    var isModelLoaded: Bool { get async }
    func loadModel() async throws
    func transcribe(_ audio: AudioChunk) async throws -> TranscriptionResult
}
