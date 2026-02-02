import Foundation

/// Storage for assistant configuration, persisted as JSON
/// Marked nonisolated to allow use from any actor context
nonisolated final class ConfigStore: Sendable {
    let configFileURL: URL

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    nonisolated init(baseDirectory: URL? = nil) {
        let directory: URL

        if let baseDirectory = baseDirectory {
            directory = baseDirectory
        } else {
            let appSupport = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            )[0]
            directory = appSupport.appendingPathComponent("HeyLlama", isDirectory: true)
        }

        // Ensure directory exists
        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        self.configFileURL = directory.appendingPathComponent("config.json")
    }

    nonisolated func loadConfig() -> AssistantConfig {
        guard FileManager.default.fileExists(atPath: configFileURL.path) else {
            return .default
        }

        do {
            let data = try Data(contentsOf: configFileURL)
            return try decoder.decode(AssistantConfig.self, from: data)
        } catch {
            print("Failed to load config: \(error)")
            return .default
        }
    }

    nonisolated func saveConfig(_ config: AssistantConfig) throws {
        let data = try encoder.encode(config)
        try data.write(to: configFileURL, options: .atomic)
    }
}
