// MARK: - Temporarily disabled due to FluidAudio malloc bug
// The tests themselves pass, but FluidAudio causes a malloc double-free
// when this test suite runs. This appears to be a bug in FluidAudio's
// static initialization that conflicts with XCTest.
// Re-enable once FluidAudio fixes this issue.

#if ENABLE_COMMAND_PROCESSOR_TESTS

import XCTest
@testable import HeyLlama

final class CommandProcessorTests: XCTestCase {

    var processor: CommandProcessor!

    override func setUp() {
        super.setUp()
        processor = CommandProcessor()
    }

    func testNoWakeWordReturnsNil() {
        let result = processor.extractCommand(from: "Hello world")
        XCTAssertNil(result)
    }

    func testTypoInWakeWordReturnsNil() {
        let result = processor.extractCommand(from: "Hey Lama what time is it")
        XCTAssertNil(result)
    }

    func testCorrectWakeWordExtractsCommand() {
        let result = processor.extractCommand(from: "Hey Llama what time is it")
        XCTAssertEqual(result, "what time is it")
    }

    func testCaseInsensitiveMatchingLowercase() {
        let result = processor.extractCommand(from: "hey llama, turn off the lights")
        XCTAssertEqual(result, "turn off the lights")
    }

    func testCaseInsensitiveMatchingUppercase() {
        let result = processor.extractCommand(from: "HEY LLAMA test")
        XCTAssertEqual(result, "test")
    }

    func testCaseInsensitiveMatchingMixed() {
        let result = processor.extractCommand(from: "HeY LlAmA mixed case")
        XCTAssertEqual(result, "mixed case")
    }

    func testWakeWordAloneReturnsNil() {
        let result = processor.extractCommand(from: "Hey Llama")
        XCTAssertNil(result)
    }

    func testWakeWordWithOnlyWhitespaceReturnsNil() {
        let result = processor.extractCommand(from: "Hey Llama   ")
        XCTAssertNil(result)
    }

    func testWakeWordMidSentenceExtractsAfter() {
        let result = processor.extractCommand(from: "before Hey Llama after")
        XCTAssertEqual(result, "after")
    }

    func testCommandIsTrimmed() {
        let result = processor.extractCommand(from: "Hey Llama   spaced   ")
        XCTAssertEqual(result, "spaced")
    }

    func testCommandWithLeadingComma() {
        let result = processor.extractCommand(from: "Hey Llama, what's the weather")
        XCTAssertEqual(result, "what's the weather")
    }

    func testMultipleWakeWordsUsesFirst() {
        let result = processor.extractCommand(from: "Hey Llama say Hey Llama")
        XCTAssertEqual(result, "say Hey Llama")
    }

    func testCustomWakePhrase() {
        let customProcessor = CommandProcessor(wakePhrase: "ok computer")
        let result = customProcessor.extractCommand(from: "Ok Computer play music")
        XCTAssertEqual(result, "play music")
    }

    func testContainsWakeWordTrue() {
        XCTAssertTrue(processor.containsWakeWord(in: "Hey Llama test"))
    }

    func testContainsWakeWordFalse() {
        XCTAssertFalse(processor.containsWakeWord(in: "Hello world"))
    }

    func testContainsWakeWordCaseInsensitive() {
        XCTAssertTrue(processor.containsWakeWord(in: "hey llama test"))
        XCTAssertTrue(processor.containsWakeWord(in: "HEY LLAMA test"))
    }
}

#endif
