import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var onboardingState = OnboardingState()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Progress indicator
            if onboardingState.currentStep != .welcome && onboardingState.currentStep != .complete {
                ProgressView(value: stepProgress)
                    .padding(.horizontal)
                    .padding(.top)
            }

            // Main content
            Group {
                switch onboardingState.currentStep {
                case .welcome:
                    WelcomeStepView(onboardingState: onboardingState)
                case .enterName:
                    EnterNameStepView(onboardingState: onboardingState)
                case .recording:
                    RecordingStepView(onboardingState: onboardingState, appState: appState)
                case .confirmSpeaker:
                    ConfirmSpeakerStepView(onboardingState: onboardingState, appState: appState)
                case .addAnother:
                    AddAnotherStepView(onboardingState: onboardingState)
                case .complete:
                    CompleteStepView(onboardingState: onboardingState, dismiss: { dismiss() })
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
        }
        .frame(width: 500, height: 450)
    }

    private var stepProgress: Double {
        switch onboardingState.currentStep {
        case .welcome: return 0
        case .enterName: return 0.2
        case .recording: return 0.4
        case .confirmSpeaker: return 0.6
        case .addAnother: return 0.8
        case .complete: return 1.0
        }
    }
}

// MARK: - Welcome Step

struct WelcomeStepView: View {
    @ObservedObject var onboardingState: OnboardingState

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.accentColor)

            Text("Welcome to Hey Llama")
                .font(.title)
                .fontWeight(.bold)

            Text("Before we begin, we need to set up voice recognition so Hey Llama can identify who's speaking.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            VStack(alignment: .leading, spacing: 8) {
                Label("Personalized responses", systemImage: "person.fill")
                Label("Multi-user support", systemImage: "person.2.fill")
                Label("Better accuracy over time", systemImage: "chart.line.uptrend.xyaxis")
            }
            .font(.subheadline)
            .foregroundColor(.secondary)

            Spacer()

            Button("Get Started") {
                onboardingState.nextStep()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }
}

// MARK: - Enter Name Step

struct EnterNameStepView: View {
    @ObservedObject var onboardingState: OnboardingState
    @FocusState private var isNameFocused: Bool

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "person.badge.plus")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)

            Text("What's your name?")
                .font(.title2)
                .fontWeight(.semibold)

            Text("This will help Hey Llama identify you and personalize responses.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            TextField("Enter your name", text: $onboardingState.speakerName)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 250)
                .focused($isNameFocused)
                .onSubmit {
                    if !onboardingState.speakerName.isEmpty {
                        onboardingState.nextStep()
                    }
                }

            Spacer()

            HStack {
                Button("Back") {
                    onboardingState.previousStep()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Continue") {
                    onboardingState.nextStep()
                }
                .buttonStyle(.borderedProminent)
                .disabled(onboardingState.speakerName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .onAppear {
            isNameFocused = true
        }
    }
}

// MARK: - Recording Step

struct RecordingStepView: View {
    @ObservedObject var onboardingState: OnboardingState
    @ObservedObject var appState: AppState
    @StateObject private var recorder = EnrollmentRecorder()
    @State private var isPreparing = false
    @State private var permissionError: String?

    var body: some View {
        VStack(spacing: 20) {
            Text("Voice Registration")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Recording for \(onboardingState.speakerName)")
                .foregroundColor(.secondary)

            // Progress
            HStack {
                ForEach(0..<EnrollmentPrompts.count, id: \.self) { index in
                    Circle()
                        .fill(circleColor(for: index))
                        .frame(width: 12, height: 12)
                }
            }
            .padding(.vertical)

            // Current phrase
            VStack(spacing: 12) {
                Text("Please say:")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(onboardingState.currentPhrase)
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
            }

            // Recording indicator
            if recorder.isRecording {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 12, height: 12)
                    Text("Recording... speak now, pause when done")
                        .foregroundColor(.red)
                }
                .padding()
            }

            // Permission error
            if let error = permissionError {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
                    .multilineTextAlignment(.center)
            }

            // Audio level indicator
            AudioLevelBar(level: recorder.isRecording ? recorder.audioLevel : 0)
                .frame(height: 8)
                .padding(.horizontal)

            Spacer()

            // Record button
            if isPreparing {
                ProgressView("Requesting microphone access...")
            } else if !onboardingState.allPhrasesRecorded {
                Button(action: toggleRecording) {
                    HStack {
                        Image(systemName: recorder.isRecording ? "stop.fill" : "mic.fill")
                        Text(recorder.isRecording ? "Stop Recording" : "Start Recording")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(recorder.isRecording ? .red : .accentColor)
                .controlSize(.large)
            }

            if onboardingState.allPhrasesRecorded {
                Button("Continue") {
                    onboardingState.nextStep()
                }
                .buttonStyle(.borderedProminent)
            }

            HStack {
                Button("Back") {
                    recorder.cleanup()
                    onboardingState.previousStep()
                }
                .buttonStyle(.bordered)

                Spacer()
            }
        }
        .onDisappear {
            recorder.cleanup()
        }
    }

    private func circleColor(for index: Int) -> Color {
        if index < onboardingState.recordedSamples.count {
            return .green
        } else if index == onboardingState.currentPhraseIndex && recorder.isRecording {
            return .red
        } else {
            return .gray.opacity(0.3)
        }
    }

    private func toggleRecording() {
        if recorder.isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        isPreparing = true
        permissionError = nil

        Task {
            let prepared = await recorder.prepare()
            isPreparing = false

            if prepared {
                recorder.startRecording { [self] sample in
                    // Only add sample if we haven't collected all phrases yet
                    guard !onboardingState.allPhrasesRecorded else {
                        recorder.cleanup()
                        return
                    }
                    onboardingState.addRecordedSample(sample)

                    // Stop recording if we just completed all phrases
                    if onboardingState.allPhrasesRecorded {
                        recorder.cleanup()
                    }
                }
            } else {
                permissionError = recorder.errorMessage ?? "Failed to access microphone"
            }
        }
    }

    private func stopRecording() {
        if let sample = recorder.stopRecording() {
            onboardingState.addRecordedSample(sample)
        }
    }
}

// MARK: - Audio Level Bar

struct AudioLevelBar: View {
    let level: Float

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))

                RoundedRectangle(cornerRadius: 4)
                    .fill(levelColor)
                    .frame(width: geometry.size.width * CGFloat(min(level * 10, 1.0)))
            }
        }
    }

    private var levelColor: Color {
        if level > 0.1 { return .green }
        else if level > 0.05 { return .yellow }
        else { return .gray }
    }
}

// MARK: - Confirm Speaker Step

struct ConfirmSpeakerStepView: View {
    @ObservedObject var onboardingState: OnboardingState
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(spacing: 24) {
            if onboardingState.isProcessing {
                ProgressView("Processing voice samples...")
                    .padding()
            } else if let error = onboardingState.errorMessage {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 48))
                    .foregroundColor(.red)

                Text("Enrollment Failed")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text(error)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                Button("Try Again") {
                    onboardingState.errorMessage = nil
                    onboardingState.previousStep()
                }
                .buttonStyle(.borderedProminent)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.green)

                Text("Voice Registered!")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("\(onboardingState.speakerName)'s voice has been successfully enrolled.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)

                Spacer()

                Button("Continue") {
                    onboardingState.nextStep()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .onAppear {
            enrollSpeaker()
        }
    }

    private func enrollSpeaker() {
        onboardingState.isProcessing = true

        Task {
            do {
                let speaker = try await appState.coordinator.enrollSpeaker(
                    name: onboardingState.speakerName,
                    samples: onboardingState.recordedSamples
                )
                await MainActor.run {
                    onboardingState.addEnrolledSpeaker(speaker)
                    onboardingState.isProcessing = false
                }
            } catch {
                await MainActor.run {
                    onboardingState.errorMessage = error.localizedDescription
                    onboardingState.isProcessing = false
                }
            }
        }
    }
}

// MARK: - Add Another Step

struct AddAnotherStepView: View {
    @ObservedObject var onboardingState: OnboardingState

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)

            Text("Add Another Person?")
                .font(.title2)
                .fontWeight(.semibold)

            Text("You can enroll another person now, or add more people later from Settings.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            // Show enrolled speakers
            if !onboardingState.enrolledSpeakers.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Enrolled speakers:")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    ForEach(onboardingState.enrolledSpeakers) { speaker in
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text(speaker.name)
                        }
                    }
                }
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
            }

            Spacer()

            VStack(spacing: 12) {
                Button("Add Another Person") {
                    onboardingState.resetForAnotherSpeaker()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Button("Finish Setup") {
                    onboardingState.nextStep()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
    }
}

// MARK: - Complete Step

struct CompleteStepView: View {
    @ObservedObject var onboardingState: OnboardingState
    let dismiss: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)

            Text("You're All Set!")
                .font(.title)
                .fontWeight(.bold)

            Text("Hey Llama is ready to use. Just say \"Hey Llama\" followed by your command.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                Text("Enrolled speakers:")
                    .font(.caption)
                    .foregroundColor(.secondary)

                ForEach(onboardingState.enrolledSpeakers) { speaker in
                    HStack {
                        Image(systemName: "person.fill")
                            .foregroundColor(.accentColor)
                        Text(speaker.name)
                    }
                }
            }
            .padding()
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)

            Spacer()

            Button("Start Using Hey Llama") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }
}

#Preview {
    OnboardingView()
        .environmentObject(AppState())
}
