import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            LLMSettingsView()
                .tabItem {
                    Label("AI", systemImage: "brain")
                }

            SkillsSettingsView()
                .tabItem {
                    Label("Skills", systemImage: "wand.and.stars")
                }

            AudioSettingsPlaceholder()
                .tabItem {
                    Label("Audio", systemImage: "waveform")
                }

            SpeakersSettingsView()
                .tabItem {
                    Label("Speakers", systemImage: "person.2")
                }

            APISettingsPlaceholder()
                .tabItem {
                    Label("API", systemImage: "network")
                }
        }
        .frame(width: 480, height: 520)
    }
}

struct GeneralSettingsView: View {
    var body: some View {
        VStack {
            Spacer()
            Text("Wake phrase, launch at login, and other general settings will be added in Milestone 7.")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding()
            Spacer()
        }
    }
}

struct AudioSettingsPlaceholder: View {
    var body: some View {
        VStack {
            Spacer()
            Text("Audio device selection, silence threshold, and microphone testing will be added in Milestone 7.")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding()
            Spacer()
        }
    }
}

struct APISettingsPlaceholder: View {
    var body: some View {
        VStack {
            Spacer()
            Text("HTTP and WebSocket API settings for satellite devices will be added in Milestone 6.")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding()
            Spacer()
        }
    }
}

#Preview {
    SettingsView()
}
