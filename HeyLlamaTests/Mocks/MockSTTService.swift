import Foundation
@testable import HeyLlama

actor MockSTTService: STTServiceProtocol {
    var mockResult: TranscriptionResult?
    var mockError: Error?
    var loadModelCalled = false
    var transcribeCalls: [AudioChunk] = []

    private var _isModelLoaded = false

    var isModelLoaded: Bool {
        _isModelLoaded
    }

    func setModelLoaded(_ loaded: Bool) {
        _isModelLoaded = loaded
    }

    func setMockResult(_ result: TranscriptionResult) {
        self.mockResult = result
        self.mockError = nil
    }

    func setMockError(_ error: Error) {
        self.mockError = error
        self.mockResult = nil
    }

    func loadModel() async throws {
        loadModelCalled = true
        if let error = mockError {
            throw error
        }
        _isModelLoaded = true
    }

    func transcribe(_ audio: AudioChunk) async throws -> TranscriptionResult {
        transcribeCalls.append(audio)

        if let error = mockError {
            throw error
        }

        guard let result = mockResult else {
            return TranscriptionResult(
                text: "",
                confidence: 0,
                language: "en",
                processingTimeMs: 0
            )
        }

        return result
    }

    func resetCallTracking() {
        loadModelCalled = false
        transcribeCalls = []
    }
}
