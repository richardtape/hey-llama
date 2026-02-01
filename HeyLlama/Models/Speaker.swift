import Foundation

/// Response mode for speaker output preferences
nonisolated enum ResponseMode: String, Codable, Sendable, CaseIterable {
    case speaker  // Speak through Mac speakers
    case api      // Return response via API only
    case both     // Both speaker and API
}

/// Metadata tracking for speaker usage
nonisolated struct SpeakerMetadata: Codable, Equatable, Sendable {
    var commandCount: Int
    var lastSeenAt: Date?
    var preferredResponseMode: ResponseMode

    nonisolated init(
        commandCount: Int = 0,
        lastSeenAt: Date? = nil,
        preferredResponseMode: ResponseMode = .speaker
    ) {
        self.commandCount = commandCount
        self.lastSeenAt = lastSeenAt
        self.preferredResponseMode = preferredResponseMode
    }
}

/// Enrolled speaker profile with voice embedding
nonisolated struct Speaker: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var name: String
    let enrolledAt: Date
    var embedding: SpeakerEmbedding
    var metadata: SpeakerMetadata

    nonisolated init(
        id: UUID = UUID(),
        name: String,
        embedding: SpeakerEmbedding,
        enrolledAt: Date = Date(),
        metadata: SpeakerMetadata = SpeakerMetadata()
    ) {
        self.id = id
        self.name = name
        self.embedding = embedding
        self.enrolledAt = enrolledAt
        self.metadata = metadata
    }
}
