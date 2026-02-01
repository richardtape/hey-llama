import XCTest
@testable import HeyLlama

final class EnrollmentPromptsTests: XCTestCase {

    func testPromptsCount() {
        XCTAssertEqual(EnrollmentPrompts.phrases.count, 5)
    }

    func testPromptsContainWakeWord() {
        let phrasesWithWakeWord = EnrollmentPrompts.phrases.filter {
            $0.lowercased().contains("hey llama")
        }
        XCTAssertGreaterThanOrEqual(phrasesWithWakeWord.count, 2)
    }

    func testGetPhraseWithNameSubstitution() {
        let phrase = EnrollmentPrompts.getPhrase(at: 2, forName: "Alice")
        XCTAssertTrue(phrase.contains("Alice"))
        XCTAssertFalse(phrase.contains("[NAME]"))
    }

    func testGetPhraseWithoutNamePlaceholder() {
        let phrase = EnrollmentPrompts.getPhrase(at: 0, forName: "Bob")
        // First phrase shouldn't have name placeholder
        XCTAssertFalse(phrase.contains("[NAME]"))
    }

    func testGetPhraseIndexWrapping() {
        let phrase = EnrollmentPrompts.getPhrase(at: 10, forName: "Carol")
        // Should wrap around - index 10 % 5 = 0
        XCTAssertEqual(phrase, EnrollmentPrompts.getPhrase(at: 0, forName: "Carol"))
    }

    func testAllPhrasesAreNonEmpty() {
        for phrase in EnrollmentPrompts.phrases {
            XCTAssertFalse(phrase.isEmpty)
            XCTAssertGreaterThan(phrase.count, 10)
        }
    }

    func testPhrasesHaveVariedLength() {
        let lengths = EnrollmentPrompts.phrases.map { $0.count }
        let minLength = lengths.min()!
        let maxLength = lengths.max()!

        // Should have some variety in length
        XCTAssertGreaterThan(maxLength - minLength, 10)
    }
}
