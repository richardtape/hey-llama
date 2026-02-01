import SwiftUI

struct MenuBarView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // App info
            Text("Hey Llama")
                .font(.headline)
            Text("v0.1.0")
                .font(.caption)
                .foregroundColor(.secondary)

            Divider()

            // Status (placeholder - will be dynamic in M1)
            HStack {
                Image(systemName: "waveform")
                Text("Idle")
            }
            .foregroundColor(.secondary)

            Divider()

            // Preferences
            SettingsLink {
                Text("Preferences...")
            }
            .keyboardShortcut(",", modifiers: .command)

            Divider()

            // Quit
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
        .padding(8)
        .frame(width: 200)
    }
}

#Preview {
    MenuBarView()
}
