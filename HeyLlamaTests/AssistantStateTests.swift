import XCTest
@testable import HeyLlama

final class AssistantStateTests: XCTestCase {

    func testIdleStatusIcon() {
        let state = AssistantState.idle
        XCTAssertEqual(state.statusIcon, "waveform.slash")
    }

    func testListeningStatusIcon() {
        let state = AssistantState.listening
        XCTAssertEqual(state.statusIcon, "waveform")
    }

    func testCapturingStatusIcon() {
        let state = AssistantState.capturing
        XCTAssertEqual(state.statusIcon, "waveform.badge.mic")
    }

    func testProcessingStatusIcon() {
        let state = AssistantState.processing
        XCTAssertEqual(state.statusIcon, "brain")
    }

    func testRespondingStatusIcon() {
        let state = AssistantState.responding
        XCTAssertEqual(state.statusIcon, "speaker.wave.2")
    }

    func testErrorStatusIcon() {
        let state = AssistantState.error("Test error")
        XCTAssertEqual(state.statusIcon, "exclamationmark.triangle")
    }

    func testIdleStatusText() {
        let state = AssistantState.idle
        XCTAssertEqual(state.statusText, "Idle")
    }

    func testListeningStatusText() {
        let state = AssistantState.listening
        XCTAssertEqual(state.statusText, "Listening...")
    }

    func testCapturingStatusText() {
        let state = AssistantState.capturing
        XCTAssertEqual(state.statusText, "Capturing...")
    }

    func testProcessingStatusText() {
        let state = AssistantState.processing
        XCTAssertEqual(state.statusText, "Processing...")
    }

    func testRespondingStatusText() {
        let state = AssistantState.responding
        XCTAssertEqual(state.statusText, "Speaking...")
    }

    func testErrorStatusTextIncludesMessage() {
        let state = AssistantState.error("Microphone unavailable")
        XCTAssertEqual(state.statusText, "Error: Microphone unavailable")
    }

    func testEquatableForSameCase() {
        XCTAssertEqual(AssistantState.idle, AssistantState.idle)
        XCTAssertEqual(AssistantState.listening, AssistantState.listening)
    }

    func testEquatableForDifferentCases() {
        XCTAssertNotEqual(AssistantState.idle, AssistantState.listening)
    }

    func testEquatableForErrorWithSameMessage() {
        XCTAssertEqual(AssistantState.error("Test"), AssistantState.error("Test"))
    }

    func testEquatableForErrorWithDifferentMessage() {
        XCTAssertNotEqual(AssistantState.error("A"), AssistantState.error("B"))
    }
}
