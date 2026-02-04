import Foundation
import MusicKit

// MARK: - Arguments

/// Arguments for the Apple Music now playing skill (none).
///
/// IMPORTANT: When modifying this struct, you MUST update `argumentsJSONSchema`
/// to match. Run `AppleMusicNowPlayingSkillTests.testArgumentsMatchJSONSchema` to verify.
struct AppleMusicNowPlayingArguments: Codable {}

// MARK: - Skill Definition

/// Skill to report the currently playing Apple Music item.
struct AppleMusicNowPlayingSkill: Skill {

    // MARK: - Skill Metadata

    static let id = "music.now_playing"
    static let name = "Now Playing"
    static let skillDescription = "Identify the currently playing Apple Music track."
    static let requiredPermissions: [SkillPermission] = [.music]
    static let includesInResponseAgent = true

    // MARK: - Arguments Type Alias

    typealias Arguments = AppleMusicNowPlayingArguments

    // MARK: - JSON Schema

    static let argumentsJSONSchema = """
        {
            "type": "object",
            "properties": {},
            "required": []
        }
        """

    // MARK: - Execution

    func execute(arguments: Arguments, context: SkillContext) async throws -> SkillResult {
        try await MusicKitHelpers.ensureAuthorized()

        let player = ApplicationMusicPlayer.shared
        guard let entry = player.queue.currentEntry else {
            return SkillResult(text: "Nothing is playing right now.")
        }

        if let song = entry.item as? Song {
            let response = "Now playing \(song.title) by \(song.artistName)."
            let summary = SkillSummary(skillId: Self.id, status: .success, summary: response)
            return SkillResult(text: response, summary: summary)
        }

        if let playlist = entry.item as? Playlist {
            let response = "Now playing the playlist \(playlist.name)."
            let summary = SkillSummary(skillId: Self.id, status: .success, summary: response)
            return SkillResult(text: response, summary: summary)
        }

        if let album = entry.item as? Album {
            let response = "Now playing the album \(album.title) by \(album.artistName)."
            let summary = SkillSummary(skillId: Self.id, status: .success, summary: response)
            return SkillResult(text: response, summary: summary)
        }

        let response = "Something is playing, but I couldn't read the details."
        let summary = SkillSummary(skillId: Self.id, status: .failed, summary: response)
        return SkillResult(text: response, summary: summary)
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
