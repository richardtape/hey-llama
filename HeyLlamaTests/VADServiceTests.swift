import XCTest
@testable import HeyLlama

final class VADServiceTests: XCTestCase {

    // Use small chunk size for tests so each chunk triggers processing
    private let testChunkSize = 480

    func testReturnsSilenceWhenNoSpeechDetected() async {
        let mockVAD = MockVADProcessor()
        mockVAD.probabilitiesToReturn = [0.1, 0.2, 0.1]
        let service = VADService(vadProcessor: mockVAD, targetChunkSize: testChunkSize)

        let chunk = AudioChunk(samples: [Float](repeating: 0.0, count: testChunkSize))

        let result1 = await service.processAsync(chunk)
        let result2 = await service.processAsync(chunk)
        let result3 = await service.processAsync(chunk)

        XCTAssertEqual(result1, .silence)
        XCTAssertEqual(result2, .silence)
        XCTAssertEqual(result3, .silence)
    }

    func testReturnsSpeechStartOnFirstSpeechDetection() async {
        let mockVAD = MockVADProcessor()
        mockVAD.probabilitiesToReturn = [0.1, 0.8] // silence, then speech
        let service = VADService(vadProcessor: mockVAD, targetChunkSize: testChunkSize)

        let chunk = AudioChunk(samples: [Float](repeating: 0.0, count: testChunkSize))

        let result1 = await service.processAsync(chunk)
        let result2 = await service.processAsync(chunk)

        XCTAssertEqual(result1, .silence)
        XCTAssertEqual(result2, .speechStart)
    }

    func testReturnsSpeechContinueDuringOngoingSpeech() async {
        let mockVAD = MockVADProcessor()
        mockVAD.probabilitiesToReturn = [0.8, 0.9, 0.85] // all speech
        let service = VADService(vadProcessor: mockVAD, targetChunkSize: testChunkSize)

        let chunk = AudioChunk(samples: [Float](repeating: 0.0, count: testChunkSize))

        let result1 = await service.processAsync(chunk)
        let result2 = await service.processAsync(chunk)
        let result3 = await service.processAsync(chunk)

        XCTAssertEqual(result1, .speechStart)
        XCTAssertEqual(result2, .speechContinue)
        XCTAssertEqual(result3, .speechContinue)
    }

    func testReturnsSpeechEndAfterSilenceThresholdExceeded() async {
        let mockVAD = MockVADProcessor()
        // Speech, then 10 frames of silence (threshold)
        var probs: [Float] = [0.8] // speech start
        probs.append(contentsOf: [Float](repeating: 0.1, count: 10)) // silence frames
        mockVAD.probabilitiesToReturn = probs
        let service = VADService(vadProcessor: mockVAD, targetChunkSize: testChunkSize)

        let chunk = AudioChunk(samples: [Float](repeating: 0.0, count: testChunkSize))

        let startResult = await service.processAsync(chunk)
        XCTAssertEqual(startResult, .speechStart)

        // 9 silence frames should return speechContinue
        for _ in 0..<9 {
            let result = await service.processAsync(chunk)
            XCTAssertEqual(result, .speechContinue)
        }

        // 10th silence frame should return speechEnd
        let endResult = await service.processAsync(chunk)
        XCTAssertEqual(endResult, .speechEnd)
    }

    func testBriefPausesReturnSpeechContinue() async {
        let mockVAD = MockVADProcessor()
        // Speech, 5 silence frames (under threshold), then speech again
        var probs: [Float] = [0.8] // speech start
        probs.append(contentsOf: [Float](repeating: 0.1, count: 5)) // brief pause
        probs.append(0.8) // speech resumes
        mockVAD.probabilitiesToReturn = probs
        let service = VADService(vadProcessor: mockVAD, targetChunkSize: testChunkSize)

        let chunk = AudioChunk(samples: [Float](repeating: 0.0, count: testChunkSize))

        let startResult = await service.processAsync(chunk)
        XCTAssertEqual(startResult, .speechStart)

        // 5 silence frames should all return speechContinue
        for _ in 0..<5 {
            let result = await service.processAsync(chunk)
            XCTAssertEqual(result, .speechContinue)
        }

        // Speech resumes - should still be speechContinue (not a new start)
        let resumeResult = await service.processAsync(chunk)
        XCTAssertEqual(resumeResult, .speechContinue)
    }

    func testResetClearsInternalState() async {
        let mockVAD = MockVADProcessor()
        mockVAD.probabilitiesToReturn = [0.8, 0.9, 0.8] // all speech
        let service = VADService(vadProcessor: mockVAD, targetChunkSize: testChunkSize)

        let chunk = AudioChunk(samples: [Float](repeating: 0.0, count: testChunkSize))

        let result1 = await service.processAsync(chunk)
        let result2 = await service.processAsync(chunk)

        XCTAssertEqual(result1, .speechStart)
        XCTAssertEqual(result2, .speechContinue)

        service.reset()
        mockVAD.reset()

        // After reset, next speech should be a new speechStart
        let result3 = await service.processAsync(chunk)
        XCTAssertEqual(result3, .speechStart)
    }

    func testThresholdIsFiftyPercent() async {
        let mockVAD = MockVADProcessor()
        mockVAD.probabilitiesToReturn = [0.49, 0.50, 0.51]
        let service = VADService(vadProcessor: mockVAD, targetChunkSize: testChunkSize)

        let chunk = AudioChunk(samples: [Float](repeating: 0.0, count: testChunkSize))

        let result1 = await service.processAsync(chunk)
        let result2 = await service.processAsync(chunk)
        let result3 = await service.processAsync(chunk)

        XCTAssertEqual(result1, .silence) // 0.49 < 0.5
        XCTAssertEqual(result2, .silence) // 0.50 not > 0.5
        XCTAssertEqual(result3, .speechStart) // 0.51 > 0.5
    }
}
