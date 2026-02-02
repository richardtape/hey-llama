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

            Divider()

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
        .frame(width: 240)
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
        case _ where appState.statusText.hasPrefix("Error"):
            return .red
        default:
            return .secondary
        }
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
