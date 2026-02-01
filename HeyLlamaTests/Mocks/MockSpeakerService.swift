import Foundation
@testable import HeyLlama

actor MockSpeakerService: SpeakerServiceProtocol {
    var mockIdentifyResult: Speaker?
    var mockEnrollResult: Speaker?
    var mockError: Error?
    var loadModelCalled = false
    var identifyCalls: [AudioChunk] = []
    var enrollCalls: [(name: String, samples: [AudioChunk])] = []
    var removeCalls: [Speaker] = []
    var updateCalls: [Speaker] = []

    private var _isModelLoaded = false
    private var _enrolledSpeakers: [Speaker] = []

    var isModelLoaded: Bool {
        _isModelLoaded
    }

    var enrolledSpeakers: [Speaker] {
        _enrolledSpeakers
    }

    func setModelLoaded(_ loaded: Bool) {
        _isModelLoaded = loaded
    }

    func setEnrolledSpeakers(_ speakers: [Speaker]) {
        _enrolledSpeakers = speakers
    }

    func setMockIdentifyResult(_ speaker: Speaker?) {
        mockIdentifyResult = speaker
        mockError = nil
    }

    func setMockEnrollResult(_ speaker: Speaker) {
        mockEnrollResult = speaker
        mockError = nil
    }

    func setMockError(_ error: Error) {
        mockError = error
    }

    func loadModel() async throws {
        loadModelCalled = true
        if let error = mockError {
            throw error
        }
        _isModelLoaded = true
    }

    func identify(_ audio: AudioChunk) async -> Speaker? {
        identifyCalls.append(audio)
        return mockIdentifyResult
    }

    func enroll(name: String, samples: [AudioChunk]) async throws -> Speaker {
        enrollCalls.append((name: name, samples: samples))

        if let error = mockError {
            throw error
        }

        if let result = mockEnrollResult {
            _enrolledSpeakers.append(result)
            return result
        }

        // Create default mock speaker
        let embedding = SpeakerEmbedding(vector: [Float](repeating: 0.5, count: 256), modelVersion: "mock")
        let speaker = Speaker(name: name, embedding: embedding)
        _enrolledSpeakers.append(speaker)
        return speaker
    }

    func remove(_ speaker: Speaker) async throws {
        removeCalls.append(speaker)
        if let error = mockError {
            throw error
        }
        _enrolledSpeakers.removeAll { $0.id == speaker.id }
    }

    func updateSpeaker(_ speaker: Speaker) async throws {
        updateCalls.append(speaker)
        if let error = mockError {
            throw error
        }
        if let index = _enrolledSpeakers.firstIndex(where: { $0.id == speaker.id }) {
            _enrolledSpeakers[index] = speaker
        }
    }

    func resetCallTracking() {
        loadModelCalled = false
        identifyCalls = []
        enrollCalls = []
        removeCalls = []
        updateCalls = []
    }
}
