import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var appState: AppState

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
                } else {
                    Text(appState.statusText)
                }
            }
            .foregroundColor(statusColor)

            // Transcription section
            if let transcription = appState.lastTranscription, !transcription.isEmpty {
                Divider()

                VStack(alignment: .leading, spacing: 2) {
                    Text("Last heard:")
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
        .frame(width: 220)
    }

    private var statusColor: Color {
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

#Preview {
    MenuBarView()
        .environmentObject(AppState())
}
