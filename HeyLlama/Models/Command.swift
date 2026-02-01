import Foundation

struct Command: Sendable {
    let rawText: String
    let commandText: String
    let speaker: Speaker?
    let source: AudioSource
    let timestamp: Date
    let confidence: Float

    init(
        rawText: String,
        commandText: String,
        speaker: Speaker? = nil,
        source: AudioSource,
        confidence: Float
    ) {
        self.rawText = rawText
        self.commandText = commandText
        self.speaker = speaker
        self.source = source
        self.timestamp = Date()
        self.confidence = confidence
    }
}

enum ConversationRole: String, Sendable {
    case user
    case assistant
}

struct ConversationTurn: Sendable {
    let role: ConversationRole
    let content: String
    let timestamp: Date

    init(role: ConversationRole, content: String) {
        self.role = role
        self.content = content
        self.timestamp = Date()
    }
}

struct CommandContext: Sendable {
    let command: String
    let speaker: Speaker?
    let source: AudioSource
    let timestamp: Date
    let conversationHistory: [ConversationTurn]?

    init(
        command: String,
        speaker: Speaker? = nil,
        source: AudioSource,
        conversationHistory: [ConversationTurn]? = nil
    ) {
        self.command = command
        self.speaker = speaker
        self.source = source
        self.timestamp = Date()
        self.conversationHistory = conversationHistory
    }
}
