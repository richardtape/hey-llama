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

            HStack {
                Image(systemName: appState.statusIcon)
                Text(appState.statusText)
            }
            .foregroundColor(statusColor)

            AudioLevelIndicator(level: appState.audioLevel)
                .frame(height: 4)

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
        .frame(width: 200)
    }

    private var statusColor: Color {
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
