import SwiftUI

struct SpeakersSettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var speakerToDelete: Speaker?
    @State private var showDeleteConfirmation = false
    @Environment(\.openWindow) private var openWindow

    // Observe the enrolled speakers via AppState (reactive)
    private var speakers: [Speaker] {
        appState.enrolledSpeakers
    }

    var body: some View {
        Form {
            Section {
                if speakers.isEmpty {
                    Text("No speakers enrolled")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(speakers) { speaker in
                        SpeakerRow(speaker: speaker, onDelete: {
                            speakerToDelete = speaker
                            showDeleteConfirmation = true
                        })
                    }
                }
            } header: {
                HStack {
                    Text("Enrolled Speakers")
                    Spacer()
                    Button(action: {
                        openWindow(id: "enrollment")
                    }) {
                        Label("Add Speaker", systemImage: "plus")
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .task {
            // Load speakers on first appearance
            await appState.coordinator.refreshEnrolledSpeakers()
        }
        .confirmationDialog(
            "Remove Speaker",
            isPresented: $showDeleteConfirmation,
            presenting: speakerToDelete
        ) { speaker in
            Button("Remove \(speaker.name)", role: .destructive) {
                removeSpeaker(speaker)
            }
            Button("Cancel", role: .cancel) {}
        } message: { speaker in
            Text("Are you sure you want to remove \(speaker.name)? This cannot be undone.")
        }
    }

    private func removeSpeaker(_ speaker: Speaker) {
        Task {
            await appState.coordinator.removeSpeaker(speaker)
        }
    }
}

struct SpeakerRow: View {
    let speaker: Speaker
    let onDelete: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(speaker.name)
                    .font(.headline)

                HStack(spacing: 16) {
                    Label("\(speaker.metadata.commandCount) commands", systemImage: "text.bubble")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if let lastSeen = speaker.metadata.lastSeenAt {
                        Label(lastSeen.formatted(date: .abbreviated, time: .shortened), systemImage: "clock")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            Text("Enrolled \(speaker.enrolledAt.formatted(date: .abbreviated, time: .omitted))")
                .font(.caption)
                .foregroundColor(.secondary)

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    SpeakersSettingsView()
        .environmentObject(AppState())
        .frame(width: 400, height: 300)
}
