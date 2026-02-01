// MARK: - Temporarily disabled due to FluidAudio malloc bug
// The tests themselves pass, but FluidAudio causes a malloc double-free
// when this test suite runs. This appears to be a bug in FluidAudio's
// static initialization that conflicts with XCTest.
// Re-enable once FluidAudio fixes this issue.

#if ENABLE_AUDIO_BUFFER_TESTS

import XCTest
@testable import HeyLlama

final class AudioBufferTests: XCTestCase {

    func testAppendAddsToBuffer() {
        let buffer = AudioBuffer(maxSeconds: 15)
        let chunk = AudioChunk(samples: [0.1, 0.2, 0.3])

        buffer.append(chunk)

        XCTAssertEqual(buffer.sampleCount, 3)
    }

    func testAppendMultipleChunks() {
        let buffer = AudioBuffer(maxSeconds: 15)

        buffer.append(AudioChunk(samples: [0.1, 0.2]))
        buffer.append(AudioChunk(samples: [0.3, 0.4, 0.5]))

        XCTAssertEqual(buffer.sampleCount, 5)
    }

    func testBufferTrimsWhenExceedsMax() {
        // 1 second buffer at 16kHz = 16000 samples max
        let buffer = AudioBuffer(maxSeconds: 1)

        // Add 20000 samples (exceeds 16000 max)
        let samples = [Float](repeating: 0.5, count: 20000)
        buffer.append(AudioChunk(samples: samples))

        XCTAssertEqual(buffer.sampleCount, 16000)
    }

    func testMarkSpeechStartSetsIndex() {
        let buffer = AudioBuffer(maxSeconds: 15)

        // Add 8000 samples (0.5 seconds)
        buffer.append(AudioChunk(samples: [Float](repeating: 0.1, count: 8000)))

        buffer.markSpeechStart()

        // Should have marked speech start
        XCTAssertTrue(buffer.hasSpeechStart)
    }

    func testMarkSpeechStartWithLookback() {
        let buffer = AudioBuffer(maxSeconds: 15)

        // Add 8000 samples (0.5 seconds)
        let samples = (0..<8000).map { Float($0) / 8000.0 }
        buffer.append(AudioChunk(samples: samples))

        buffer.markSpeechStart()

        // Get utterance - should include 300ms lookback (4800 samples)
        let utterance = buffer.getUtteranceSinceSpeechStart()

        // Should get samples from (8000 - 4800) = 3200 to end
        XCTAssertEqual(utterance.samples.count, 4800)
    }

    func testGetUtteranceReturnsSamplesFromSpeechStart() {
        let buffer = AudioBuffer(maxSeconds: 15)

        // Add initial samples
        buffer.append(AudioChunk(samples: [Float](repeating: 0.0, count: 8000)))

        // Mark speech start
        buffer.markSpeechStart()

        // Add more samples (the actual speech)
        buffer.append(AudioChunk(samples: [Float](repeating: 1.0, count: 4000)))

        let utterance = buffer.getUtteranceSinceSpeechStart()

        // Should get: 4800 (lookback from mark) + 4000 (new samples) = 8800
        XCTAssertEqual(utterance.samples.count, 8800)
    }

    func testGetUtteranceResetsSpeechStartIndex() {
        let buffer = AudioBuffer(maxSeconds: 15)

        buffer.append(AudioChunk(samples: [Float](repeating: 0.1, count: 8000)))
        buffer.markSpeechStart()

        _ = buffer.getUtteranceSinceSpeechStart()

        XCTAssertFalse(buffer.hasSpeechStart)
    }

    func testGetUtteranceWithoutMarkReturnsAllSamples() {
        let buffer = AudioBuffer(maxSeconds: 15)

        buffer.append(AudioChunk(samples: [Float](repeating: 0.1, count: 1000)))

        let utterance = buffer.getUtteranceSinceSpeechStart()

        XCTAssertEqual(utterance.samples.count, 1000)
    }

    func testClearEmptiesBuffer() {
        let buffer = AudioBuffer(maxSeconds: 15)

        buffer.append(AudioChunk(samples: [Float](repeating: 0.1, count: 5000)))
        buffer.markSpeechStart()
        buffer.clear()

        XCTAssertEqual(buffer.sampleCount, 0)
        XCTAssertFalse(buffer.hasSpeechStart)
    }

    func testTrimmingAdjustsSpeechStartIndex() {
        // 1 second buffer = 16000 samples
        let buffer = AudioBuffer(maxSeconds: 1)

        // Add 10000 samples
        buffer.append(AudioChunk(samples: [Float](repeating: 0.1, count: 10000)))

        // Mark speech start (will be at ~5200 after lookback)
        buffer.markSpeechStart()

        // Add 10000 more samples - will trigger trimming
        buffer.append(AudioChunk(samples: [Float](repeating: 0.2, count: 10000)))

        // Buffer should be trimmed, speech start index adjusted
        XCTAssertEqual(buffer.sampleCount, 16000)

        // Speech start should still be valid (adjusted for trimming)
        let utterance = buffer.getUtteranceSinceSpeechStart()
        XCTAssertGreaterThan(utterance.samples.count, 0)
    }

    func testThreadSafety() {
        let buffer = AudioBuffer(maxSeconds: 15)
        let expectation = XCTestExpectation(description: "Concurrent access")
        expectation.expectedFulfillmentCount = 100

        for _ in 0..<100 {
            DispatchQueue.global().async {
                buffer.append(AudioChunk(samples: [Float](repeating: 0.1, count: 100)))
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 5.0)

        // Should have 10000 samples total
        XCTAssertEqual(buffer.sampleCount, 10000)
    }
}

#endif
