import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Hey Llama")
                .font(.headline)
            Text("v0.1.0")
                .font(.caption)
                .foregroundColor(.secondary)

            Divider()

            HStack {
                Text("Pause Listening")
                Spacer()
                Toggle("", isOn: Binding(
                    get: { appState.isListeningPaused },
                    set: { newValue in
                        appState.toggleListeningPaused(newValue)
                    }
                ))
                .toggleStyle(.switch)
                .labelsHidden()
            }

            Divider()

            // Status section
            HStack {
                Image(systemName: appState.statusIcon)
                if appState.isModelLoading {
                    Text("Loading model...")
                } else if appState.requiresOnboarding {
                    Text("Setup required")
                } else {
                    Text(appState.statusText)
                }
            }
            .foregroundColor(statusColor)

            // LLM configuration warning
            if !appState.requiresOnboarding && !appState.llmConfigured {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("AI not configured")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }

            if !appState.requiresOnboarding {
                AudioLevelIndicator(level: appState.audioLevel)
                    .frame(height: 4)
            }

            // Transcription section with speaker
            if let transcription = appState.lastTranscription, !transcription.isEmpty {
                Divider()

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("Last heard")
                        if let speaker = appState.currentSpeaker {
                            Text("(\(speaker.name)):")
                                .foregroundColor(.accentColor)
                        } else {
                            Text("(Guest):")
                                .foregroundColor(.secondary)
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)

                    Text(transcription)
                        .font(.caption)
                        .lineLimit(3)
                }
            }

            // Command section
            if let command = appState.lastCommand, !command.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Command:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(command)
                        .font(.caption)
                        .foregroundColor(.green)
                        .lineLimit(2)
                }
            }

            // Response section
            if let response = appState.lastResponse, !response.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Response:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(response)
                        .font(.caption)
                        .foregroundColor(responseColor)
                        .lineLimit(4)
                }
            }

            Divider()

            if appState.isMusicControlsVisible {
                HStack(spacing: 8) {
                    Text(nowPlayingText)
                        .font(.caption)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Spacer()

                    Button {
                        appState.playPreviousTrack()
                    } label: {
                        Image(systemName: "backward.fill")
                    }
                    .buttonStyle(.plain)

                    Button {
                        appState.playPauseMusic()
                    } label: {
                        Image(systemName: appState.musicIsPlaying ? "pause.fill" : "play.fill")
                    }
                    .buttonStyle(.plain)

                    Button {
                        appState.playNextTrack()
                    } label: {
                        Image(systemName: "forward.fill")
                    }
                    .buttonStyle(.plain)
                }

                Divider()
            }

            // Actions
            if appState.requiresOnboarding {
                Button("Complete Setup...") {
                    openWindow(id: "onboarding")
                }
            } else {
                Button("Add Speaker...") {
                    openWindow(id: "enrollment")
                }
            }

            SettingsLink {
                Text("Preferences...")
            }
            .keyboardShortcut(",", modifiers: .command)

            Divider()

            Button("Quit") {
                appState.shutdown()
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
        .padding(8)
        .frame(width: 260)
    }

    private var statusColor: Color {
        if appState.requiresOnboarding {
            return .orange
        }
        if appState.isModelLoading {
            return .orange
        }

        switch appState.statusText {
        case "Capturing...":
            return .green
        case "Processing...":
            return .orange
        case "Speaking...":
            return .blue
        case _ where appState.statusText.hasPrefix("Error"):
            return .red
        default:
            return .secondary
        }
    }

    private var responseColor: Color {
        if let response = appState.lastResponse, response.hasPrefix("[Error") {
            return .red
        }
        return .primary
    }

    private var nowPlayingText: String {
        let title = appState.musicNowPlayingTitle
        let artist = appState.musicNowPlayingArtist
        if title.isEmpty {
            return "Nothing playing"
        }
        if artist.isEmpty {
            return title
        }
        return "\(title) — \(artist)"
    }
}

struct AudioLevelIndicator: View {
    let level: Float

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.gray.opacity(0.3))

                RoundedRectangle(cornerRadius: 2)
                    .fill(levelColor)
                    .frame(width: geometry.size.width * CGFloat(min(level * 10, 1.0)))
            }
        }
    }

    private var levelColor: Color {
        if level > 0.1 {
            return .green
        } else if level > 0.05 {
            return .yellow
        } else {
            return .gray
        }
    }
}

#Preview {
    MenuBarView()
        .environmentObject(AppState())
}
