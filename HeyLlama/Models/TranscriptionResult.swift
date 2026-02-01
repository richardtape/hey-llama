import Foundation

struct WordTiming: Equatable, Sendable {
    let word: String
    let startTime: TimeInterval
    let endTime: TimeInterval
    let confidence: Float
}

struct TranscriptionResult: Equatable, Sendable {
    let text: String
    let confidence: Float
    let language: String
    let processingTimeMs: Int
    let words: [WordTiming]?

    init(
        text: String,
        confidence: Float,
        language: String,
        processingTimeMs: Int,
        words: [WordTiming]? = nil
    ) {
        self.text = text
        self.confidence = confidence
        self.language = language
        self.processingTimeMs = processingTimeMs
        self.words = words
    }
}
