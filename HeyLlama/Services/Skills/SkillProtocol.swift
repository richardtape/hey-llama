import Foundation

/// Context passed to skills when they execute
struct SkillContext: Sendable {
    let speaker: Speaker?
    let source: AudioSource
    let timestamp: Date

    init(speaker: Speaker? = nil, source: AudioSource = .localMic, timestamp: Date = Date()) {
        self.speaker = speaker
        self.source = source
        self.timestamp = timestamp
    }
}

/// Result returned by a skill after execution
struct SkillResult {
    let text: String
    let data: [String: Any]?

    init(text: String, data: [String: Any]? = nil) {
        self.text = text
        self.data = data
    }
}

/// Errors that can occur during skill execution
enum SkillError: Error, LocalizedError, Equatable {
    case permissionDenied(SkillPermission)
    case permissionNotRequested(SkillPermission)
    case invalidArguments(String)
    case executionFailed(String)
    case skillNotFound(String)
    case skillDisabled(String)

    var errorDescription: String? {
        switch self {
        case .permissionDenied(let permission):
            return "\(permission.displayName) permission was denied"
        case .permissionNotRequested(let permission):
            return "\(permission.displayName) permission has not been requested"
        case .invalidArguments(let message):
            return "Invalid arguments: \(message)"
        case .executionFailed(let message):
            return "Skill execution failed: \(message)"
        case .skillNotFound(let id):
            return "Skill not found: \(id)"
        case .skillDisabled(let id):
            return "Skill is disabled: \(id)"
        }
    }
}
