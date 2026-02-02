import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            AudioSettingsPlaceholder()
                .tabItem {
                    Label("Audio", systemImage: "waveform")
                }

            SpeakersSettingsView()
                .tabItem {
                    Label("Speakers", systemImage: "person.2")
                }

            Text("API settings coming in Milestone 5")
                .tabItem {
                    Label("API", systemImage: "network")
                }
        }
        .frame(width: 500, height: 350)
    }
}

struct GeneralSettingsView: View {
    var body: some View {
        Form {
            Section {
                Text("Wake phrase, launch at login, and other general settings will be added in Milestone 6.")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
}

struct AudioSettingsPlaceholder: View {
    var body: some View {
        Form {
            Section {
                Text("Audio device selection, silence threshold, and microphone testing will be added in Milestone 6.")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
}

#Preview {
    SettingsView()
}
