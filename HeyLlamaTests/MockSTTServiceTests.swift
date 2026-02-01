// MARK: - Temporarily disabled due to FluidAudio malloc bug
// The tests themselves pass, but FluidAudio causes a malloc double-free
// when this test suite runs. This appears to be a bug in FluidAudio's
// static initialization that conflicts with XCTest.
// Re-enable once FluidAudio fixes this issue.

#if ENABLE_STT_TESTS

import XCTest
@testable import HeyLlama

final class MockSTTServiceTests: XCTestCase {

    func testLoadModelSetsIsModelLoaded() async throws {
        let mock = MockSTTService()

        let loadedBefore = await mock.isModelLoaded
        XCTAssertFalse(loadedBefore)

        try await mock.loadModel()

        let loadedAfter = await mock.isModelLoaded
        XCTAssertTrue(loadedAfter)
    }

    func testLoadModelCallIsTracked() async throws {
        let mock = MockSTTService()

        let calledBefore = await mock.loadModelCalled
        XCTAssertFalse(calledBefore)

        try await mock.loadModel()

        let calledAfter = await mock.loadModelCalled
        XCTAssertTrue(calledAfter)
    }

    func testTranscribeReturnsMockResult() async throws {
        let mock = MockSTTService()
        let expectedResult = TranscriptionResult(
            text: "Hello world",
            confidence: 0.95,
            language: "en",
            processingTimeMs: 100
        )
        await mock.setMockResult(expectedResult)

        let chunk = AudioChunk(samples: [Float](repeating: 0.0, count: 480))
        let result = try await mock.transcribe(chunk)

        XCTAssertEqual(result.text, "Hello world")
        XCTAssertEqual(result.confidence, 0.95)
    }

    func testTranscribeTracksCallsWithAudioChunks() async throws {
        let mock = MockSTTService()
        await mock.setMockResult(TranscriptionResult(text: "", confidence: 0, language: "en", processingTimeMs: 0))

        let chunk1 = AudioChunk(samples: [Float](repeating: 0.1, count: 100))
        let chunk2 = AudioChunk(samples: [Float](repeating: 0.2, count: 200))

        _ = try await mock.transcribe(chunk1)
        _ = try await mock.transcribe(chunk2)

        let calls = await mock.transcribeCalls
        XCTAssertEqual(calls.count, 2)
        XCTAssertEqual(calls[0].samples.count, 100)
        XCTAssertEqual(calls[1].samples.count, 200)
    }

    func testTranscribeThrowsMockError() async {
        let mock = MockSTTService()
        await mock.setMockError(NSError(domain: "test", code: 1, userInfo: nil))

        let chunk = AudioChunk(samples: [])

        do {
            _ = try await mock.transcribe(chunk)
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertEqual((error as NSError).domain, "test")
        }
    }

    func testResetCallTracking() async throws {
        let mock = MockSTTService()
        await mock.setMockResult(TranscriptionResult(text: "", confidence: 0, language: "en", processingTimeMs: 0))

        try await mock.loadModel()
        _ = try await mock.transcribe(AudioChunk(samples: []))

        await mock.resetCallTracking()

        let loadModelCalled = await mock.loadModelCalled
        let transcribeCalls = await mock.transcribeCalls

        XCTAssertFalse(loadModelCalled)
        XCTAssertTrue(transcribeCalls.isEmpty)
    }
}

#endif
