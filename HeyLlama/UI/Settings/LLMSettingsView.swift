import SwiftUI

struct LLMSettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var config: AssistantConfig
    @State private var isSaving = false
    @State private var saveError: String?
    @State private var testResult: String?
    @State private var isTesting = false

    private let configStore: ConfigStore
    private let labelWidth: CGFloat = 110

    init() {
        let store = ConfigStore()
        self.configStore = store
        self._config = State(initialValue: store.loadConfig())
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Provider Selection
                    GroupBox("Provider") {
                        VStack(alignment: .leading, spacing: 12) {
                            Picker("Provider", selection: $config.llm.provider) {
                                Text("Apple Intelligence").tag(LLMProvider.appleIntelligence)
                                Text("OpenAI Compatible").tag(LLMProvider.openAICompatible)
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()

                            // Fixed-height container for provider settings
                            providerSettingsView
                                .frame(minHeight: 140, alignment: .top)
                        }
                        .padding(.vertical, 8)
                    }

                    // Conversation Settings
                    GroupBox("Conversation") {
                        VStack(alignment: .leading, spacing: 10) {
                            LabeledContent("Context timeout:") {
                                Stepper(
                                    config.llm.conversationTimeoutMinutes == 1 ? "1 minute" : "\(config.llm.conversationTimeoutMinutes) minutes",
                                    value: $config.llm.conversationTimeoutMinutes,
                                    in: 1...30
                                )
                                .frame(width: 140)
                            }

                            LabeledContent("Max history:") {
                                Stepper(
                                    config.llm.maxConversationTurns == 1 ? "1 turn" : "\(config.llm.maxConversationTurns) turns",
                                    value: $config.llm.maxConversationTurns,
                                    in: 2...20
                                )
                                .frame(width: 140)
                            }

                            Text("Older history is excluded from AI requests to manage context size.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 8)
                    }

                    // System Prompt
                    GroupBox("System Prompt") {
                        VStack(alignment: .leading, spacing: 8) {
                            TextEditor(text: $config.llm.systemPrompt)
                                .font(.system(.body, design: .monospaced))
                                .frame(height: 70)
                                .scrollContentBackground(.hidden)
                                .background(Color(nsColor: .textBackgroundColor))
                                .border(Color(nsColor: .separatorColor), width: 1)

                            HStack {
                                Text("Use {speaker_name} as a placeholder.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                Spacer()

                                Button("Reset to Default") {
                                    config.llm.systemPrompt = LLMConfig.defaultSystemPrompt
                                }
                                .font(.caption)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
                .padding(16)
            }

            // Footer with actions
            Divider()

            HStack {
                if let error = saveError {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundColor(.red)
                        .font(.caption)
                } else if let result = testResult {
                    Label(
                        result.contains("Success") ? "Connection successful" : result,
                        systemImage: result.contains("Success") ? "checkmark.circle" : "xmark.circle"
                    )
                    .foregroundColor(result.contains("Success") ? .green : .red)
                    .font(.caption)
                    .lineLimit(1)
                }

                Spacer()

                HStack(spacing: 12) {
                    Button("Test") {
                        testConnection()
                    }
                    .disabled(isTesting || !isCurrentProviderConfigured)

                    Button("Save") {
                        saveConfig()
                    }
                    .disabled(isSaving)
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    @ViewBuilder
    private var providerSettingsView: some View {
        if config.llm.provider == .appleIntelligence {
            appleIntelligenceSection
        } else {
            openAICompatibleSection
        }
    }

    private var appleIntelligenceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "apple.logo")
                Text("On-device AI using Foundation Models")
                    .fontWeight(.medium)
            }

            Text("Fast, private responses processed entirely on your Mac. Requires macOS 26+ with Apple Silicon.")
                .font(.callout)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
    }

    private var openAICompatibleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            LabeledContent("Base URL:") {
                TextField("", text: $config.llm.openAICompatible.baseURL, prompt: Text("http://localhost:11434/v1"))
                    .textFieldStyle(.roundedBorder)
            }

            LabeledContent("Model:") {
                TextField("", text: $config.llm.openAICompatible.model, prompt: Text("llama3.2"))
                    .textFieldStyle(.roundedBorder)
            }

            LabeledContent("API Key:") {
                SecureField("", text: Binding(
                    get: { config.llm.openAICompatible.apiKey ?? "" },
                    set: { config.llm.openAICompatible.apiKey = $0.isEmpty ? nil : $0 }
                ), prompt: Text("Optional"))
                .textFieldStyle(.roundedBorder)
            }

            LabeledContent("Timeout:") {
                Stepper(
                    "\(config.llm.openAICompatible.timeoutSeconds)s",
                    value: $config.llm.openAICompatible.timeoutSeconds,
                    in: 10...300,
                    step: 10
                )
                .frame(width: 100)
            }

            if !config.llm.openAICompatible.isConfigured {
                Label("Enter base URL and model to enable.", systemImage: "info.circle")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
    }

    private var isCurrentProviderConfigured: Bool {
        switch config.llm.provider {
        case .appleIntelligence:
            return true // Will check actual availability when implemented
        case .openAICompatible:
            return config.llm.openAICompatible.isConfigured
        }
    }

    private func saveConfig() {
        isSaving = true
        saveError = nil
        testResult = nil

        do {
            try configStore.saveConfig(config)

            // Reload config in the coordinator to apply changes
            Task {
                await appState.reloadConfig()
                isSaving = false
            }
        } catch {
            saveError = error.localizedDescription
            isSaving = false
        }
    }

    private func testConnection() {
        isTesting = true
        testResult = nil
        saveError = nil

        Task {
            do {
                if config.llm.provider == .appleIntelligence {
                    await MainActor.run {
                        testResult = "Apple Intelligence: not yet implemented"
                        isTesting = false
                    }
                    return
                }

                let provider = OpenAICompatibleProvider(
                    config: config.llm.openAICompatible,
                    systemPromptTemplate: config.llm.systemPrompt
                )

                _ = try await provider.complete(
                    prompt: "Respond with: OK",
                    context: nil,
                    conversationHistory: []
                )

                await MainActor.run {
                    testResult = "Success"
                    isTesting = false
                }
            } catch {
                await MainActor.run {
                    testResult = error.localizedDescription
                    isTesting = false
                }
            }
        }
    }
}

#Preview {
    LLMSettingsView()
        .environmentObject(AppState())
        .frame(width: 480, height: 500)
}
