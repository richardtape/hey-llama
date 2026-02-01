import XCTest
@testable import HeyLlama

final class TranscriptionResultTests: XCTestCase {

    func testTranscriptionResultInit() {
        let result = TranscriptionResult(
            text: "Hello world",
            confidence: 0.95,
            language: "en",
            processingTimeMs: 250
        )

        XCTAssertEqual(result.text, "Hello world")
        XCTAssertEqual(result.confidence, 0.95)
        XCTAssertEqual(result.language, "en")
        XCTAssertEqual(result.processingTimeMs, 250)
        XCTAssertNil(result.words)
    }

    func testTranscriptionResultWithWordTimings() {
        let words = [
            WordTiming(word: "Hello", startTime: 0.0, endTime: 0.5, confidence: 0.98),
            WordTiming(word: "world", startTime: 0.6, endTime: 1.0, confidence: 0.92)
        ]

        let result = TranscriptionResult(
            text: "Hello world",
            confidence: 0.95,
            language: "en",
            processingTimeMs: 250,
            words: words
        )

        XCTAssertEqual(result.words?.count, 2)
        XCTAssertEqual(result.words?[0].word, "Hello")
        XCTAssertEqual(result.words?[1].endTime, 1.0)
    }

    func testWordTimingInit() {
        let timing = WordTiming(
            word: "test",
            startTime: 1.5,
            endTime: 2.0,
            confidence: 0.88
        )

        XCTAssertEqual(timing.word, "test")
        XCTAssertEqual(timing.startTime, 1.5)
        XCTAssertEqual(timing.endTime, 2.0)
        XCTAssertEqual(timing.confidence, 0.88)
    }

    func testTranscriptionResultEquatable() {
        let result1 = TranscriptionResult(text: "test", confidence: 0.9, language: "en", processingTimeMs: 100)
        let result2 = TranscriptionResult(text: "test", confidence: 0.9, language: "en", processingTimeMs: 100)
        let result3 = TranscriptionResult(text: "other", confidence: 0.9, language: "en", processingTimeMs: 100)

        XCTAssertEqual(result1, result2)
        XCTAssertNotEqual(result1, result3)
    }
}
