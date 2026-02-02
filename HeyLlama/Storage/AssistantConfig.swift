import Foundation

/// Main configuration for the assistant
struct AssistantConfig: Equatable, Sendable {
    var wakePhrase: String
    var wakeWordSensitivity: Float
    var apiPort: UInt16
    var apiEnabled: Bool
    var llm: LLMConfig

    nonisolated init(
        wakePhrase: String = "hey llama",
        wakeWordSensitivity: Float = 0.5,
        apiPort: UInt16 = 8765,
        apiEnabled: Bool = true,
        llm: LLMConfig = .default
    ) {
        self.wakePhrase = wakePhrase
        self.wakeWordSensitivity = wakeWordSensitivity
        self.apiPort = apiPort
        self.apiEnabled = apiEnabled
        self.llm = llm
    }

    nonisolated static var `default`: AssistantConfig {
        AssistantConfig()
    }
}

// MARK: - Codable conformance with nonisolated methods
extension AssistantConfig: Codable {
    private enum CodingKeys: String, CodingKey {
        case wakePhrase, wakeWordSensitivity, apiPort, apiEnabled, llm
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        wakePhrase = try container.decode(String.self, forKey: .wakePhrase)
        wakeWordSensitivity = try container.decode(Float.self, forKey: .wakeWordSensitivity)
        apiPort = try container.decode(UInt16.self, forKey: .apiPort)
        apiEnabled = try container.decode(Bool.self, forKey: .apiEnabled)
        llm = try container.decode(LLMConfig.self, forKey: .llm)
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(wakePhrase, forKey: .wakePhrase)
        try container.encode(wakeWordSensitivity, forKey: .wakeWordSensitivity)
        try container.encode(apiPort, forKey: .apiPort)
        try container.encode(apiEnabled, forKey: .apiEnabled)
        try container.encode(llm, forKey: .llm)
    }
}
