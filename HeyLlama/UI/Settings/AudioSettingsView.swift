import SwiftUI

struct AudioSettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var config: AssistantConfig
    @State private var devices: [AudioOutputDevice] = []
    @State private var saveError: String?

    private let configStore: ConfigStore

    init() {
        let store = ConfigStore()
        self.configStore = store
        self._config = State(initialValue: store.loadConfig())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Audio Output")
                .font(.headline)

            if let error = saveError {
                Label(error, systemImage: "exclamationmark.triangle")
                    .foregroundColor(.red)
                    .font(.caption)
            }

            Picker("Preferred Output", selection: Binding(
                get: { config.audio.preferredOutputDeviceUID ?? "" },
                set: { newValue in
                    config.audio.preferredOutputDeviceUID = newValue.isEmpty ? nil : newValue
                    persistConfig()
                }
            )) {
                Text("System Default").tag("")
                ForEach(devices, id: \.uid) { device in
                    Text(device.name).tag(device.uid)
                }
            }
            .pickerStyle(.menu)

            Toggle("Switch system output when music plays", isOn: Binding(
                get: { config.audio.autoSwitchOutputForMusic },
                set: { newValue in
                    config.audio.autoSwitchOutputForMusic = newValue
                    persistConfig()
                }
            ))

            Button("Set Current Output As Preferred") {
                if let uid = AudioOutputDeviceHelper.getDefaultOutputDeviceUID() {
                    config.audio.preferredOutputDeviceUID = uid
                    persistConfig()
                }
            }

            Spacer()
        }
        .padding(16)
        .onAppear(perform: reloadDevices)
    }

    private func reloadDevices() {
        devices = AudioOutputDeviceHelper.getOutputDevices()
    }

    private func persistConfig() {
        saveError = nil
        do {
            try configStore.saveConfig(config)
            Task { await appState.reloadConfig() }
        } catch {
            saveError = error.localizedDescription
        }
    }
}

#Preview {
    AudioSettingsView()
        .environmentObject(AppState())
}
