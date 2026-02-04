import Foundation
import MusicKit

// MARK: - Arguments

/// Arguments for the Apple Music add-to-playlist skill.
///
/// IMPORTANT: When modifying this struct, you MUST update `argumentsJSONSchema`
/// to match. Run `AppleMusicAddToPlaylistSkillTests.testArgumentsMatchJSONSchema` to verify.
struct AppleMusicAddToPlaylistArguments: Codable {
    /// The track to add (may include artist)
    let trackQuery: String

    /// The playlist name
    let playlistName: String

    /// Optional source override: auto, library, catalog
    let source: String?

    /// Set to true after confirmation to create a playlist if missing
    let createPlaylistIfMissing: Bool?
}

// MARK: - Skill Definition

/// Skill to add a track to a playlist in the user's Apple Music library.
struct AppleMusicAddToPlaylistSkill: Skill {

    // MARK: - Skill Metadata

    static let id = "music.add_to_playlist"
    static let name = "Add Track to Playlist"
    static let skillDescription = "Add a song to an Apple Music playlist. If the playlist does not exist, ask to create it."
    static let requiredPermissions: [SkillPermission] = [.music]
    static let includesInResponseAgent = true

    // MARK: - Arguments Type Alias

    typealias Arguments = AppleMusicAddToPlaylistArguments

    // MARK: - JSON Schema

    static let argumentsJSONSchema = """
        {
            "type": "object",
            "properties": {
                "trackQuery": {
                    "type": "string",
                    "description": "The song to add (may include artist)"
                },
                "playlistName": {
                    "type": "string",
                    "description": "The playlist name"
                },
                "source": {
                    "type": "string",
                    "enum": ["auto", "library", "catalog"],
                    "description": "Optional source override. Use library for local items, catalog for Apple Music. Default is auto."
                },
                "createPlaylistIfMissing": {
                    "type": "boolean",
                    "description": "Set true to create the playlist if missing (used after confirmation)."
                }
            },
            "required": ["trackQuery", "playlistName"]
        }
        """

    // MARK: - Execution

    func execute(arguments: Arguments, context: SkillContext) async throws -> SkillResult {
        try await MusicKitHelpers.ensureAuthorized()

        let source = MusicKitHelpers.parseSource(arguments.source)
        var usedCatalog = false

        if source == .catalog {
            let canPlay = await MusicKitHelpers.canPlayCatalogContent()
            if !canPlay {
                return catalogSubscriptionRequiredResult()
            }
        }
        let song = try await resolveSong(query: arguments.trackQuery, source: source, usedCatalog: &usedCatalog)

        guard let song else {
            return SkillResult(text: "I couldn't find a song matching '\(arguments.trackQuery)'.")
        }

        if usedCatalog {
            let canPlay = await MusicKitHelpers.canPlayCatalogContent()
            if !canPlay {
                return catalogSubscriptionRequiredResult()
            }
        }

        let lookup = try await MusicKitHelpers.lookupPlaylist(named: arguments.playlistName)
        if let playlist = lookup.exactMatch {
            try await MusicKitHelpers.addSong(song, to: playlist)
            let response = "Added \(song.title) to your \(playlist.name) playlist."
            let summary = SkillSummary(skillId: Self.id, status: .success, summary: response)
            return SkillResult(text: response, summary: summary)
        }

        if arguments.createPlaylistIfMissing == true {
            let playlist = try await MusicKitHelpers.createPlaylist(named: arguments.playlistName, with: song)
            let response = "Created the \(playlist.name) playlist and added \(song.title)."
            let summary = SkillSummary(skillId: Self.id, status: .success, summary: response)
            return SkillResult(text: response, summary: summary)
        }

        let message = playlistNotFoundMessage(
            requestedName: arguments.playlistName,
            closestMatch: lookup.closestMatchName,
            availableNames: lookup.availableNames
        )

        var data: [String: Any] = [
            "playlistName": arguments.playlistName,
            "closestPlaylist": lookup.closestMatchName ?? "",
            "availablePlaylists": lookup.availableNames
        ]

        var pendingArgs: [String: Any] = [
            "trackQuery": arguments.trackQuery,
            "playlistName": arguments.playlistName,
            "createPlaylistIfMissing": true
        ]
        if let source = arguments.source {
            pendingArgs["source"] = source
        }

        data["confirmationType"] = "yes_no"
        data["pendingAction"] = [
            "skillId": Self.id,
            "arguments": pendingArgs,
            "prompt": message
        ]

        let summary = SkillSummary(skillId: Self.id, status: .failed, summary: message)
        return SkillResult(text: message, data: data, summary: summary)
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

    // MARK: - Helpers

    private func resolveSong(query: String, source: MusicKitHelpers.Source, usedCatalog: inout Bool) async throws -> Song? {
        switch source {
        case .library:
            return try await MusicKitHelpers.searchLibrarySong(term: query)
        case .catalog:
            usedCatalog = true
            return try await MusicKitHelpers.searchCatalogSong(term: query)
        case .auto:
            if let song = try await MusicKitHelpers.searchLibrarySong(term: query) {
                return song
            }
            usedCatalog = true
            return try await MusicKitHelpers.searchCatalogSong(term: query)
        }
    }

    private func playlistNotFoundMessage(requestedName: String, closestMatch: String?, availableNames: [String]) -> String {
        var message = "I couldn't find a playlist named '\(requestedName)'."
        if let closest = closestMatch {
            message += " Did you mean '\(closest)'?"
        }
        message += " Would you like me to create it?"
        if !availableNames.isEmpty {
            let list = availableNames.joined(separator: ", ")
            message += " Available playlists: \(list)."
        }
        return message
    }

    private func catalogSubscriptionRequiredResult() -> SkillResult {
        let message = "You need an active Apple Music subscription to add catalog songs to playlists."
        let summary = SkillSummary(skillId: Self.id, status: .failed, summary: message)
        return SkillResult(text: message, summary: summary)
    }
}
