import SwiftUI

struct SpeakersSettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var speakers: [Speaker] = []
    @State private var speakerToDelete: Speaker?
    @State private var showDeleteConfirmation = false
    @State private var isLoading = false
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Form {
            Section {
                if isLoading {
                    ProgressView("Loading speakers...")
                } else if speakers.isEmpty {
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
                    Button(action: loadSpeakers) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.borderless)
                    .help("Refresh speaker list")
                    
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
            await loadSpeakersAsync()
        }
        .onAppear {
            loadSpeakers()
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

    private func loadSpeakers() {
        Task {
            await loadSpeakersAsync()
        }
    }
    
    private func loadSpeakersAsync() async {
        isLoading = true
        speakers = await appState.coordinator.getEnrolledSpeakers()
        isLoading = false
    }

    private func removeSpeaker(_ speaker: Speaker) {
        Task {
            await appState.coordinator.removeSpeaker(speaker)
            await loadSpeakersAsync()
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
