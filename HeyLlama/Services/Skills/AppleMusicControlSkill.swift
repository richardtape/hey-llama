import Foundation
import MusicKit

// MARK: - Arguments

/// Arguments for the Apple Music control skill.
///
/// IMPORTANT: When modifying this struct, you MUST update `argumentsJSONSchema`
/// to match. Run `AppleMusicControlSkillTests.testArgumentsMatchJSONSchema` to verify.
struct AppleMusicControlArguments: Codable {
    /// Playback action: pause, resume, next, previous, shuffle, repeat
    let action: String

    /// Optional mode for shuffle/repeat
    let mode: String?
}

// MARK: - Skill Definition

/// Skill to control Apple Music playback.
struct AppleMusicControlSkill: Skill {

    // MARK: - Skill Metadata

    static let id = "music.control"
    static let name = "Music Controls"
    static let skillDescription = "Control Apple Music playback (pause, resume, next, previous, shuffle, repeat). Use this only when music is already playing."
    static let requiredPermissions: [SkillPermission] = [.music]
    static let includesInResponseAgent = true

    // MARK: - Arguments Type Alias

    typealias Arguments = AppleMusicControlArguments

    // MARK: - JSON Schema

    static let argumentsJSONSchema = """
        {
            "type": "object",
            "properties": {
                "action": {
                    "type": "string",
                    "enum": ["pause", "resume", "next", "previous", "shuffle", "repeat"],
                    "description": "Playback action to perform"
                },
                "mode": {
                    "type": "string",
                    "description": "Optional mode for shuffle (on/off) or repeat (off/one/all)"
                }
            },
            "required": ["action"]
        }
        """

    // MARK: - Execution

    func execute(arguments: Arguments, context: SkillContext) async throws -> SkillResult {
        try await MusicKitHelpers.ensureAuthorized()

        let action = arguments.action.lowercased()
        let controller = MusicPlaybackController.shared

        switch action {
        case "pause":
            try await controller.pause()
            return SkillResult(text: "Paused.", data: ["listeningAction": "resume"])
        case "resume":
            let outputMessage = await MusicOutputSwitcher.attemptSwitchIfConfigured()
            try await controller.play()
            let text: String
            if let outputMessage {
                text = "Resuming playback. \(outputMessage)"
            } else {
                text = "Resuming playback."
            }
            return SkillResult(text: text, data: ["listeningAction": "pause"])
        case "next":
            try await controller.next()
            return SkillResult(text: "Skipping to the next track.")
        case "previous":
            try await controller.previous()
            return SkillResult(text: "Going back to the previous track.")
        case "shuffle":
            let mode = (arguments.mode ?? "on").lowercased()
            if mode == "off" {
                return SkillResult(text: "Shuffle off isn't supported yet.")
            }
            let didShuffle = try await controller.shuffleQueue()
            if didShuffle {
                return SkillResult(text: "Shuffling the current queue.")
            }
            return SkillResult(text: "There's nothing queued to shuffle. Try asking me to shuffle a specific playlist.")
        case "repeat":
            return SkillResult(text: "Repeat control isn't available on this platform yet.")
        default:
            throw SkillError.invalidArguments("Unsupported action: \(arguments.action)")
        }
    }

    // MARK: - Legacy API Support

    func run(argumentsJSON: String, context: SkillContext) async throws -> SkillResult {
        guard let data = argumentsJSON.data(using: .utf8) else {
            throw SkillError.invalidArguments("Invalid JSON encoding")
        }

        do {
            let args = try JSONDecoder().decode(Arguments.self, from: data)
            return try await execute(arguments: args, context: context)
        } catch let error as SkillError {
            throw error
        } catch {
            throw SkillError.invalidArguments("Failed to parse arguments: \(error.localizedDescription)")
        }
    }
}
