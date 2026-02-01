// MARK: - Temporarily disabled due to FluidAudio malloc bug
// The tests themselves pass, but FluidAudio causes a malloc double-free
// when this test suite runs. This appears to be a bug in FluidAudio's
// static initialization that conflicts with XCTest.
// Re-enable once FluidAudio fixes this issue.

#if ENABLE_ASSISTANT_STT_TESTS

import XCTest
@testable import HeyLlama

@MainActor
final class AssistantCoordinatorSTTTests: XCTestCase {

    func testCommandProcessorExtractsWakeWord() {
        let processor = CommandProcessor()

        // Test various inputs
        XCTAssertNil(processor.extractCommand(from: "Hello world"))
        XCTAssertEqual(processor.extractCommand(from: "Hey Llama what time is it"), "what time is it")
        XCTAssertEqual(processor.extractCommand(from: "hey llama turn on lights"), "turn on lights")
    }

    func testTranscriptionResultCreation() {
        let result = TranscriptionResult(
            text: "Hey Llama test command",
            confidence: 0.95,
            language: "en",
            processingTimeMs: 150
        )

        XCTAssertEqual(result.text, "Hey Llama test command")
        XCTAssertEqual(result.confidence, 0.95)
        XCTAssertEqual(result.processingTimeMs, 150)
    }

    func testCommandCreation() {
        let command = Command(
            rawText: "Hey Llama turn on the lights",
            commandText: "turn on the lights",
            source: .localMic,
            confidence: 0.92
        )

        XCTAssertEqual(command.rawText, "Hey Llama turn on the lights")
        XCTAssertEqual(command.commandText, "turn on the lights")
        XCTAssertEqual(command.source, .localMic)
    }

    func testCommandProcessorWithVariousInputs() {
        let processor = CommandProcessor()

        // No wake word
        XCTAssertNil(processor.extractCommand(from: "turn on the lights"))

        // Wake word with command
        XCTAssertEqual(processor.extractCommand(from: "Hey Llama turn on the lights"), "turn on the lights")

        // Wake word alone
        XCTAssertNil(processor.extractCommand(from: "Hey Llama"))

        // Wake word with comma
        XCTAssertEqual(processor.extractCommand(from: "Hey Llama, what's the weather"), "what's the weather")

        // Mixed case
        XCTAssertEqual(processor.extractCommand(from: "HEY LLAMA hello"), "hello")
    }
}

#endif
