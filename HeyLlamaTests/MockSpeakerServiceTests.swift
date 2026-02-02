import XCTest
@testable import HeyLlama

final class MockSpeakerServiceTests: XCTestCase {

    func testLoadModelSetsIsModelLoaded() async throws {
        let mock = MockSpeakerService()

        let loadedBefore = await mock.isModelLoaded
        XCTAssertFalse(loadedBefore)

        try await mock.loadModel()

        let loadedAfter = await mock.isModelLoaded
        XCTAssertTrue(loadedAfter)
    }

    func testIdentifyReturnsMockResult() async {
        let mock = MockSpeakerService()
        let embedding = SpeakerEmbedding(vector: [1, 2, 3], modelVersion: "1.0")
        let speaker = Speaker(name: "Alice", embedding: embedding)

        await mock.setMockIdentifyResult(speaker)

        let chunk = AudioChunk(samples: [Float](repeating: 0.0, count: 480))
        let result = await mock.identify(chunk)

        XCTAssertEqual(result?.name, "Alice")
    }

    func testIdentifyReturnsNilWhenNoMockResult() async {
        let mock = MockSpeakerService()

        let chunk = AudioChunk(samples: [Float](repeating: 0.0, count: 480))
        let result = await mock.identify(chunk)

        XCTAssertNil(result)
    }

    func testIdentifyTracksCallsWithAudioChunks() async {
        let mock = MockSpeakerService()

        let chunk1 = AudioChunk(samples: [Float](repeating: 0.1, count: 100))
        let chunk2 = AudioChunk(samples: [Float](repeating: 0.2, count: 200))

        _ = await mock.identify(chunk1)
        _ = await mock.identify(chunk2)

        let calls = await mock.identifyCalls
        XCTAssertEqual(calls.count, 2)
        XCTAssertEqual(calls[0].samples.count, 100)
        XCTAssertEqual(calls[1].samples.count, 200)
    }

    func testEnrollCreatesSpeaker() async throws {
        let mock = MockSpeakerService()

        let samples = [
            AudioChunk(samples: [Float](repeating: 0.1, count: 480)),
            AudioChunk(samples: [Float](repeating: 0.2, count: 480))
        ]

        let speaker = try await mock.enroll(name: "Bob", samples: samples)

        XCTAssertEqual(speaker.name, "Bob")

        let enrolled = await mock.enrolledSpeakers
        XCTAssertEqual(enrolled.count, 1)
        XCTAssertEqual(enrolled.first?.name, "Bob")
    }

    func testEnrollThrowsMockError() async {
        let mock = MockSpeakerService()
        await mock.setMockError(SpeakerServiceError.embeddingExtractionFailed("test"))

        let samples = [AudioChunk(samples: [])]

        do {
            _ = try await mock.enroll(name: "Carol", samples: samples)
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is SpeakerServiceError)
        }
    }

    func testRemoveSpeaker() async throws {
        let mock = MockSpeakerService()
        let embedding = SpeakerEmbedding(vector: [1], modelVersion: "1.0")
        let speaker = Speaker(name: "Dave", embedding: embedding)

        await mock.setEnrolledSpeakers([speaker])

        try await mock.remove(speaker)

        let enrolled = await mock.enrolledSpeakers
        XCTAssertTrue(enrolled.isEmpty)

        let removeCalls = await mock.removeCalls
        XCTAssertEqual(removeCalls.count, 1)
    }

    func testResetCallTracking() async throws {
        let mock = MockSpeakerService()

        try await mock.loadModel()
        _ = await mock.identify(AudioChunk(samples: []))
        _ = try await mock.enroll(name: "Test", samples: [])

        await mock.resetCallTracking()

        let loadModelCalled = await mock.loadModelCalled
        let identifyCalls = await mock.identifyCalls
        let enrollCalls = await mock.enrollCalls

        XCTAssertFalse(loadModelCalled)
        XCTAssertTrue(identifyCalls.isEmpty)
        XCTAssertTrue(enrollCalls.isEmpty)
    }
}
