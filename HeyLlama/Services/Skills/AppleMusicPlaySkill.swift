import Foundation
import MusicKit

// MARK: - Arguments

/// Arguments for the Apple Music play skill.
///
/// IMPORTANT: When modifying this struct, you MUST update `argumentsJSONSchema`
/// to match. Run `AppleMusicPlaySkillTests.testArgumentsMatchJSONSchema` to verify.
struct AppleMusicPlayArguments: Codable {
    /// The user's spoken query (song, artist, album, or playlist)
    let query: String

    /// The type of entity to play: song, album, artist, playlist
    let entityType: String

    /// Optional source override: auto, library, catalog
    let source: String?
}

// MARK: - Skill Definition

/// Skill to play Apple Music content using the system music player.
struct AppleMusicPlaySkill: Skill {

    // MARK: - Skill Metadata

    static let id = "music.play"
    static let name = "Play Music"
    static let skillDescription = "Play music by song, artist, album, or playlist using Apple Music. If the user doesn't specify a source, prefer the user's library and fall back to catalog."
    static let requiredPermissions: [SkillPermission] = [.music]
    static let includesInResponseAgent = true

    // MARK: - Arguments Type Alias

    typealias Arguments = AppleMusicPlayArguments

    // MARK: - JSON Schema

    static let argumentsJSONSchema = """
        {
            "type": "object",
            "properties": {
                "query": {
                    "type": "string",
                    "description": "The song, artist, album, or playlist to play"
                },
                "entityType": {
                    "type": "string",
                    "enum": ["song", "album", "artist", "playlist"],
                    "description": "The type of item to play"
                },
                "source": {
                    "type": "string",
                    "enum": ["auto", "library", "catalog"],
                    "description": "Optional source override. Use library for local items, catalog for Apple Music. Default is auto."
                }
            },
            "required": ["query", "entityType"]
        }
        """

    // MARK: - Execution

    func execute(arguments: Arguments, context: SkillContext) async throws -> SkillResult {
        try await MusicKitHelpers.ensureAuthorized()

        guard let entity = MusicKitHelpers.parseEntityType(arguments.entityType) else {
            throw SkillError.invalidArguments("Unsupported entityType: \(arguments.entityType)")
        }

        let source = MusicKitHelpers.parseSource(arguments.source)
        let playbackController = MusicPlaybackController.shared
        var usedCatalog = false

        if source == .catalog {
            let canPlay = await MusicKitHelpers.canPlayCatalogContent()
            if !canPlay {
                return catalogSubscriptionRequiredResult()
            }
        }

        let outputMessage = await MusicOutputSwitcher.attemptSwitchIfConfigured()

        switch entity {
        case .song:
            let song = try await resolveSong(query: arguments.query, source: source, usedCatalog: &usedCatalog)
            guard let song else {
                return SkillResult(text: "I couldn't find a song matching '\(arguments.query)'.")
            }
            if usedCatalog {
                let canPlay = await MusicKitHelpers.canPlayCatalogContent()
                if !canPlay {
                    return catalogSubscriptionRequiredResult()
                }
            }
            try await playbackController.playSong(song)
            return playbackResult(
                baseText: "Playing \(song.title) by \(song.artistName).",
                summaryText: "Playing \(song.title)",
                outputMessage: outputMessage
            )

        case .album:
            let album = try await resolveAlbum(query: arguments.query, source: source, usedCatalog: &usedCatalog)
            guard let album else {
                return SkillResult(text: "I couldn't find an album matching '\(arguments.query)'.")
            }
            if usedCatalog {
                let canPlay = await MusicKitHelpers.canPlayCatalogContent()
                if !canPlay {
                    return catalogSubscriptionRequiredResult()
                }
            }
            let tracks = try await MusicKitHelpers.loadAlbumTracks(album)
            guard !tracks.isEmpty else {
                return SkillResult(text: "I couldn't load tracks for '\(album.title)'.")
            }
            try await playbackController.playQueue(tracks)
            return playbackResult(
                baseText: "Playing the album \(album.title) by \(album.artistName).",
                summaryText: "Playing album \(album.title)",
                outputMessage: outputMessage
            )

        case .artist:
            let artist = try await resolveArtist(query: arguments.query, source: source, usedCatalog: &usedCatalog)
            guard let artist else {
                return SkillResult(text: "I couldn't find an artist matching '\(arguments.query)'.")
            }
            if usedCatalog {
                let canPlay = await MusicKitHelpers.canPlayCatalogContent()
                if !canPlay {
                    return catalogSubscriptionRequiredResult()
                }
            }
            let songs = try await resolveArtistSongs(artistName: artist.name, source: source)
            guard !songs.isEmpty else {
                return SkillResult(text: "I couldn't find songs for '\(artist.name)'.")
            }
            try await playbackController.playSongs(songs)
            return playbackResult(
                baseText: "Playing \(artist.name).",
                summaryText: "Playing artist \(artist.name)",
                outputMessage: outputMessage
            )

        case .playlist:
            let playlist = try await resolvePlaylist(query: arguments.query, source: source, usedCatalog: &usedCatalog)
            guard let playlist else {
                return SkillResult(text: "I couldn't find a playlist matching '\(arguments.query)'.")
            }
            if usedCatalog {
                let canPlay = await MusicKitHelpers.canPlayCatalogContent()
                if !canPlay {
                    return catalogSubscriptionRequiredResult()
                }
            }
            let tracks = try await MusicKitHelpers.loadPlaylistTracks(playlist)
            guard !tracks.isEmpty else {
                return SkillResult(text: "I couldn't load tracks for '\(playlist.name)'.")
            }
            try await playbackController.playQueue(tracks)
            return playbackResult(
                baseText: "Playing the playlist \(playlist.name).",
                summaryText: "Playing playlist \(playlist.name)",
                outputMessage: outputMessage
            )
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

    private func resolveAlbum(query: String, source: MusicKitHelpers.Source, usedCatalog: inout Bool) async throws -> Album? {
        switch source {
        case .library:
            return try await MusicKitHelpers.searchLibraryAlbum(term: query)
        case .catalog:
            usedCatalog = true
            return try await MusicKitHelpers.searchCatalogAlbum(term: query)
        case .auto:
            if let album = try await MusicKitHelpers.searchLibraryAlbum(term: query) {
                return album
            }
            usedCatalog = true
            return try await MusicKitHelpers.searchCatalogAlbum(term: query)
        }
    }

    private func resolveArtist(query: String, source: MusicKitHelpers.Source, usedCatalog: inout Bool) async throws -> Artist? {
        switch source {
        case .library:
            return try await MusicKitHelpers.searchLibraryArtist(term: query)
        case .catalog:
            usedCatalog = true
            return try await MusicKitHelpers.searchCatalogArtist(term: query)
        case .auto:
            if let artist = try await MusicKitHelpers.searchLibraryArtist(term: query) {
                return artist
            }
            usedCatalog = true
            return try await MusicKitHelpers.searchCatalogArtist(term: query)
        }
    }

    private func resolvePlaylist(query: String, source: MusicKitHelpers.Source, usedCatalog: inout Bool) async throws -> Playlist? {
        switch source {
        case .library:
            return try await MusicKitHelpers.searchLibraryPlaylist(term: query)
        case .catalog:
            usedCatalog = true
            return try await MusicKitHelpers.searchCatalogPlaylist(term: query)
        case .auto:
            if let playlist = try await MusicKitHelpers.searchLibraryPlaylist(term: query) {
                return playlist
            }
            usedCatalog = true
            return try await MusicKitHelpers.searchCatalogPlaylist(term: query)
        }
    }

    private func resolveArtistSongs(artistName: String, source: MusicKitHelpers.Source) async throws -> [Song] {
        switch source {
        case .library:
            return try await MusicKitHelpers.searchLibrarySongs(term: artistName, limit: 25)
        case .catalog:
            return try await MusicKitHelpers.searchCatalogSongs(term: artistName, limit: 25)
        case .auto:
            let librarySongs = try await MusicKitHelpers.searchLibrarySongs(term: artistName, limit: 25)
            if !librarySongs.isEmpty {
                return librarySongs
            }
            return try await MusicKitHelpers.searchCatalogSongs(term: artistName, limit: 25)
        }
    }

    private func catalogSubscriptionRequiredResult() -> SkillResult {
        let message = "You need an active Apple Music subscription to play catalog content."
        let summary = SkillSummary(skillId: Self.id, status: .failed, summary: message)
        return SkillResult(text: message, summary: summary)
    }

    private func playbackResult(baseText: String, summaryText: String, outputMessage: String?) -> SkillResult {
        var response = baseText
        if let outputMessage {
            response += " \(outputMessage)"
        }
        let summary = SkillSummary(skillId: Self.id, status: .success, summary: summaryText)
        let data: [String: Any] = [
            "listeningAction": "pause"
        ]
        return SkillResult(text: response, data: data, summary: summary)
    }

}
