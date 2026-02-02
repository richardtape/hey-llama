import Combine
import Foundation

enum OnboardingStep: Int, Comparable {
    case welcome = 0
    case enterName = 1
    case recording = 2
    case confirmSpeaker = 3
    case addAnother = 4
    case complete = 5

    static func < (lhs: OnboardingStep, rhs: OnboardingStep) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

@MainActor
final class OnboardingState: ObservableObject {
    @Published var currentStep: OnboardingStep = .welcome
    @Published var speakerName: String = ""
    @Published var currentPhraseIndex: Int = 0
    @Published var isRecording: Bool = false
    @Published var recordedSamples: [AudioChunk] = []
    @Published var enrolledSpeakers: [Speaker] = []
    @Published var errorMessage: String?
    @Published var isProcessing: Bool = false

    var allPhrasesRecorded: Bool {
        recordedSamples.count >= EnrollmentPrompts.count
    }

    var canComplete: Bool {
        !enrolledSpeakers.isEmpty
    }

    var currentPhrase: String {
        EnrollmentPrompts.getPhrase(at: currentPhraseIndex, forName: speakerName)
    }

    var progressFraction: Double {
        guard EnrollmentPrompts.count > 0 else { return 0 }
        return Double(recordedSamples.count) / Double(EnrollmentPrompts.count)
    }

    func nextStep() {
        guard currentStep != .complete else { return }

        switch currentStep {
        case .welcome:
            currentStep = .enterName
        case .enterName:
            currentStep = .recording
        case .recording:
            currentStep = .confirmSpeaker
        case .confirmSpeaker:
            currentStep = .addAnother
        case .addAnother:
            currentStep = .complete
        case .complete:
            break
        }
    }

    func previousStep() {
        switch currentStep {
        case .welcome:
            break
        case .enterName:
            currentStep = .welcome
        case .recording:
            currentStep = .enterName
        case .confirmSpeaker:
            currentStep = .recording
        case .addAnother:
            currentStep = .confirmSpeaker
        case .complete:
            currentStep = .addAnother
        }
    }

    func startRecording() {
        isRecording = true
        currentPhraseIndex = 0
        recordedSamples = []
        errorMessage = nil
    }

    func recordedPhrase() {
        currentPhraseIndex += 1

        if currentPhraseIndex >= EnrollmentPrompts.count {
            isRecording = false
        }
    }

    func addRecordedSample(_ sample: AudioChunk) {
        recordedSamples.append(sample)
        recordedPhrase()
    }

    func addEnrolledSpeaker(_ speaker: Speaker) {
        enrolledSpeakers.append(speaker)
    }

    func resetForAnotherSpeaker() {
        speakerName = ""
        currentPhraseIndex = 0
        recordedSamples = []
        isRecording = false
        errorMessage = nil
        currentStep = .enterName
    }

    func reset() {
        currentStep = .welcome
        speakerName = ""
        currentPhraseIndex = 0
        recordedSamples = []
        enrolledSpeakers = []
        isRecording = false
        errorMessage = nil
        isProcessing = false
    }
}
