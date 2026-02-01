import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            Text("Audio settings coming in Milestone 1")
                .tabItem {
                    Label("Audio", systemImage: "waveform")
                }

            Text("Speakers settings coming in Milestone 3")
                .tabItem {
                    Label("Speakers", systemImage: "person.2")
                }

            Text("API settings coming in Milestone 5")
                .tabItem {
                    Label("API", systemImage: "network")
                }
        }
        .frame(width: 450, height: 250)
    }
}

struct GeneralSettingsView: View {
    var body: some View {
        Form {
            Text("General settings will be added in Milestone 6")
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

#Preview {
    SettingsView()
}
