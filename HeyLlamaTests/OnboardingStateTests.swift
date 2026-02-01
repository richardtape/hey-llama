import XCTest
@testable import HeyLlama

@MainActor
final class OnboardingStateTests: XCTestCase {

    func testInitialStepIsWelcome() {
        let state = OnboardingState()
        XCTAssertEqual(state.currentStep, .welcome)
    }

    func testProgressToNextStep() {
        let state = OnboardingState()

        state.nextStep()
        XCTAssertEqual(state.currentStep, .enterName)

        state.nextStep()
        XCTAssertEqual(state.currentStep, .recording)
    }

    func testCannotProgressBeyondComplete() {
        let state = OnboardingState()

        // Progress to complete
        state.currentStep = .complete

        state.nextStep()
        XCTAssertEqual(state.currentStep, .complete)
    }

    func testPreviousStep() {
        let state = OnboardingState()
        state.currentStep = .recording

        state.previousStep()
        XCTAssertEqual(state.currentStep, .enterName)

        state.previousStep()
        XCTAssertEqual(state.currentStep, .welcome)
    }

    func testCannotGoPreviousFromWelcome() {
        let state = OnboardingState()

        state.previousStep()
        XCTAssertEqual(state.currentStep, .welcome)
    }

    func testStartRecordingForSpeaker() {
        let state = OnboardingState()
        state.speakerName = "Alice"

        state.startRecording()

        XCTAssertTrue(state.isRecording)
        XCTAssertEqual(state.currentPhraseIndex, 0)
    }

    func testAdvanceToNextPhrase() {
        let state = OnboardingState()
        state.speakerName = "Alice"
        state.startRecording()

        state.recordedPhrase()
        state.recordedPhrase()

        XCTAssertEqual(state.currentPhraseIndex, 2)
    }

    func testRecordingCompletesWhenAllPhrasesRecorded() {
        let state = OnboardingState()
        state.speakerName = "Alice"
        state.startRecording()

        for _ in 0..<EnrollmentPrompts.count {
            state.recordedPhrase()
        }

        XCTAssertFalse(state.isRecording)
        XCTAssertTrue(state.allPhrasesRecorded)
    }

    func testAddEnrolledSpeaker() {
        let state = OnboardingState()
        let embedding = SpeakerEmbedding(vector: [1], modelVersion: "1.0")
        let speaker = Speaker(name: "Alice", embedding: embedding)

        state.addEnrolledSpeaker(speaker)

        XCTAssertEqual(state.enrolledSpeakers.count, 1)
        XCTAssertEqual(state.enrolledSpeakers.first?.name, "Alice")
    }

    func testResetForAnotherSpeaker() {
        let state = OnboardingState()
        state.speakerName = "Alice"
        state.currentPhraseIndex = 3

        state.resetForAnotherSpeaker()

        XCTAssertEqual(state.speakerName, "")
        XCTAssertEqual(state.currentPhraseIndex, 0)
        XCTAssertEqual(state.currentStep, .enterName)
    }

    func testCanCompleteWithAtLeastOneSpeaker() {
        let state = OnboardingState()
        XCTAssertFalse(state.canComplete)

        let embedding = SpeakerEmbedding(vector: [1], modelVersion: "1.0")
        let speaker = Speaker(name: "Alice", embedding: embedding)
        state.addEnrolledSpeaker(speaker)

        XCTAssertTrue(state.canComplete)
    }

    func testStepOrder() {
        let steps: [OnboardingStep] = [.welcome, .enterName, .recording, .confirmSpeaker, .addAnother, .complete]

        for i in 0..<steps.count - 1 {
            XCTAssertLessThan(steps[i].rawValue, steps[i + 1].rawValue)
        }
    }
}
