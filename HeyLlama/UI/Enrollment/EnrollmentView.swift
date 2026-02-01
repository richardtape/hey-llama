import SwiftUI

/// Enrollment view for adding speakers after initial onboarding
struct EnrollmentView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var enrollmentState = EnrollmentState()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Add New Speaker")
                    .font(.headline)
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Content
            Group {
                switch enrollmentState.step {
                case .enterName:
                    EnrollmentNameView(state: enrollmentState)
                case .recording:
                    EnrollmentRecordingView(state: enrollmentState, appState: appState)
                case .processing:
                    EnrollmentProcessingView(state: enrollmentState, appState: appState, dismiss: { dismiss() })
                case .complete:
                    EnrollmentCompleteView(state: enrollmentState, dismiss: { dismiss() })
                case .error:
                    EnrollmentErrorView(state: enrollmentState)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
        }
        .frame(width: 450, height: 400)
    }
}

// MARK: - Enrollment State

enum EnrollmentStep {
    case enterName
    case recording
    case processing
    case complete
    case error
}

@MainActor
class EnrollmentState: ObservableObject {
    @Published var step: EnrollmentStep = .enterName
    @Published var speakerName: String = ""
    @Published var currentPhraseIndex: Int = 0
    @Published var recordedSamples: [AudioChunk] = []
    @Published var isRecording: Bool = false
    @Published var errorMessage: String?
    @Published var enrolledSpeaker: Speaker?

    var currentPhrase: String {
        EnrollmentPrompts.getPhrase(at: currentPhraseIndex, forName: speakerName)
    }

    var allPhrasesRecorded: Bool {
        recordedSamples.count >= EnrollmentPrompts.count
    }

    func addRecordedSample(_ sample: AudioChunk) {
        recordedSamples.append(sample)
        currentPhraseIndex += 1
    }

    func reset() {
        step = .enterName
        speakerName = ""
        currentPhraseIndex = 0
        recordedSamples = []
        isRecording = false
        errorMessage = nil
        enrolledSpeaker = nil
    }
}

// MARK: - Step Views

struct EnrollmentNameView: View {
    @ObservedObject var state: EnrollmentState
    @FocusState private var isNameFocused: Bool

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.badge.plus")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)

            Text("Enter the speaker's name")
                .font(.title3)

            TextField("Name", text: $state.speakerName)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 200)
                .focused($isNameFocused)
                .onSubmit {
                    if !state.speakerName.isEmpty {
                        state.step = .recording
                    }
                }

            Spacer()

            Button("Continue") {
                state.step = .recording
            }
            .buttonStyle(.borderedProminent)
            .disabled(state.speakerName.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .onAppear {
            isNameFocused = true
        }
    }
}

struct EnrollmentRecordingView: View {
    @ObservedObject var state: EnrollmentState
    @ObservedObject var appState: AppState
    @State private var recordingTimer: Timer?

    var body: some View {
        VStack(spacing: 16) {
            Text("Voice Registration for \(state.speakerName)")
                .font(.headline)

            // Progress dots
            HStack {
                ForEach(0..<EnrollmentPrompts.count, id: \.self) { index in
                    Circle()
                        .fill(dotColor(for: index))
                        .frame(width: 10, height: 10)
                }
            }

            // Phrase to say
            VStack(spacing: 8) {
                Text("Please say:")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(state.currentPhrase)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
            }

            // Recording indicator
            if state.isRecording {
                HStack {
                    Circle().fill(Color.red).frame(width: 10, height: 10)
                    Text("Recording...")
                }
                .foregroundColor(.red)
            }

            AudioLevelBar(level: appState.audioLevel)
                .frame(height: 6)

            Spacer()

            if state.allPhrasesRecorded {
                Button("Process Voice Samples") {
                    state.step = .processing
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button(action: toggleRecording) {
                    HStack {
                        Image(systemName: state.isRecording ? "stop.fill" : "mic.fill")
                        Text(state.isRecording ? "Stop" : "Record")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(state.isRecording ? .red : .accentColor)
            }

            Button("Back") {
                state.step = .enterName
            }
            .buttonStyle(.bordered)
        }
    }

    private func dotColor(for index: Int) -> Color {
        if index < state.recordedSamples.count { return .green }
        else if index == state.currentPhraseIndex && state.isRecording { return .red }
        else { return .gray.opacity(0.3) }
    }

    private func toggleRecording() {
        if state.isRecording {
            recordingTimer?.invalidate()
            state.isRecording = false
        } else {
            state.isRecording = true
            recordingTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
                Task { @MainActor in
                    let mockSamples = [Float](repeating: 0.1, count: 48000)
                    state.addRecordedSample(AudioChunk(samples: mockSamples))
                    state.isRecording = false
                }
            }
        }
    }
}

struct EnrollmentProcessingView: View {
    @ObservedObject var state: EnrollmentState
    @ObservedObject var appState: AppState
    let dismiss: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            ProgressView("Processing voice samples...")
                .padding()
        }
        .onAppear {
            enrollSpeaker()
        }
    }

    private func enrollSpeaker() {
        Task {
            do {
                let speaker = try await appState.coordinator.enrollSpeaker(
                    name: state.speakerName,
                    samples: state.recordedSamples
                )
                await MainActor.run {
                    state.enrolledSpeaker = speaker
                    state.step = .complete
                }
            } catch {
                await MainActor.run {
                    state.errorMessage = error.localizedDescription
                    state.step = .error
                }
            }
        }
    }
}

struct EnrollmentCompleteView: View {
    @ObservedObject var state: EnrollmentState
    let dismiss: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)

            Text("Success!")
                .font(.title2)
                .fontWeight(.semibold)

            if let speaker = state.enrolledSpeaker {
                Text("\(speaker.name) has been enrolled.")
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button("Done") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

struct EnrollmentErrorView: View {
    @ObservedObject var state: EnrollmentState

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.red)

            Text("Enrollment Failed")
                .font(.title2)
                .fontWeight(.semibold)

            Text(state.errorMessage ?? "Unknown error")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Spacer()

            Button("Try Again") {
                state.reset()
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

#Preview {
    EnrollmentView()
        .environmentObject(AppState())
}
