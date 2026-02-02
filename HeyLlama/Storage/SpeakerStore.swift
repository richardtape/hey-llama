import Foundation

/// Storage for speaker profiles, persisted as JSON
/// Marked nonisolated to allow use from any actor context
nonisolated final class SpeakerStore: Sendable {
    let speakersFileURL: URL

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

        self.speakersFileURL = directory.appendingPathComponent("speakers.json")
    }

    nonisolated func loadSpeakers() -> [Speaker] {
        guard FileManager.default.fileExists(atPath: speakersFileURL.path) else {
            return []
        }

        do {
            let data = try Data(contentsOf: speakersFileURL)
            return try decoder.decode([Speaker].self, from: data)
        } catch {
            print("Failed to load speakers: \(error)")
            return []
        }
    }

    nonisolated func saveSpeakers(_ speakers: [Speaker]) throws {
        let data = try encoder.encode(speakers)
        try data.write(to: speakersFileURL, options: .atomic)
    }

    nonisolated func hasSpeakers() -> Bool {
        let speakers = loadSpeakers()
        return !speakers.isEmpty
    }
}
