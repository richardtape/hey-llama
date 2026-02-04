import Foundation
import MusicKit

/// Helpers for Apple Music / MusicKit skills.
enum MusicKitHelpers {

    enum Source: String {
        case auto
        case library
        case catalog
    }

    enum EntityType: String {
        case song
        case album
        case artist
        case playlist
    }

    struct PlaylistLookupResult {
        let exactMatch: Playlist?
        let closestMatchName: String?
        let availableNames: [String]
    }

    // MARK: - Authorization / Subscription

    static func ensureAuthorized() async throws {
        let status = MusicAuthorization.currentStatus
        switch status {
        case .authorized:
            return
        case .notDetermined:
            let newStatus = await MusicAuthorization.request()
            guard newStatus == .authorized else {
                throw SkillError.permissionDenied(.music)
            }
        default:
            throw SkillError.permissionDenied(.music)
        }
    }

    static func canPlayCatalogContent() async -> Bool {
        do {
            let subscription = try await MusicSubscription.current
            return subscription.canPlayCatalogContent
        } catch {
            return false
        }
    }

    // MARK: - Parsing

    static func parseSource(_ value: String?) -> Source {
        guard let raw = value?.lowercased() else { return .auto }
        if raw.contains("apple music") || raw == "apple_music" {
            return .catalog
        }
        return Source(rawValue: raw) ?? .auto
    }

    static func parseEntityType(_ value: String) -> EntityType? {
        EntityType(rawValue: value.lowercased())
    }

    // MARK: - Search

    static func searchLibrarySong(term: String) async throws -> Song? {
        let request = MusicLibrarySearchRequest(term: term, types: [Song.self])
        let response = try await request.response()
        return response.songs.first
    }

    static func searchCatalogSong(term: String) async throws -> Song? {
        var request = MusicCatalogSearchRequest(term: term, types: [Song.self])
        request.limit = 5
        let response = try await request.response()
        return response.songs.first
    }

    static func searchLibrarySongs(term: String, limit: Int) async throws -> [Song] {
        var request = MusicLibrarySearchRequest(term: term, types: [Song.self])
        request.limit = limit
        let response = try await request.response()
        return Array(response.songs)
    }

    static func searchCatalogSongs(term: String, limit: Int) async throws -> [Song] {
        var request = MusicCatalogSearchRequest(term: term, types: [Song.self])
        request.limit = limit
        let response = try await request.response()
        return Array(response.songs)
    }

    static func searchLibraryAlbum(term: String) async throws -> Album? {
        let request = MusicLibrarySearchRequest(term: term, types: [Album.self])
        let response = try await request.response()
        return response.albums.first
    }

    static func searchCatalogAlbum(term: String) async throws -> Album? {
        var request = MusicCatalogSearchRequest(term: term, types: [Album.self])
        request.limit = 5
        let response = try await request.response()
        return response.albums.first
    }

    static func searchLibraryArtist(term: String) async throws -> Artist? {
        let request = MusicLibrarySearchRequest(term: term, types: [Artist.self])
        let response = try await request.response()
        return response.artists.first
    }

    static func searchCatalogArtist(term: String) async throws -> Artist? {
        var request = MusicCatalogSearchRequest(term: term, types: [Artist.self])
        request.limit = 5
        let response = try await request.response()
        return response.artists.first
    }

    static func searchLibraryPlaylist(term: String) async throws -> Playlist? {
        let request = MusicLibrarySearchRequest(term: term, types: [Playlist.self])
        let response = try await request.response()
        return response.playlists.first
    }

    static func searchCatalogPlaylist(term: String) async throws -> Playlist? {
        var request = MusicCatalogSearchRequest(term: term, types: [Playlist.self])
        request.limit = 5
        let response = try await request.response()
        return response.playlists.first
    }

    // MARK: - Playlists

    static func lookupPlaylist(named name: String) async throws -> PlaylistLookupResult {
        let request = MusicLibrarySearchRequest(term: name, types: [Playlist.self])
        let response = try await request.response()
        let playlists = Array(response.playlists)
        let availableNames = playlists.map { $0.name }

        if let exact = playlists.first(where: {
            $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame
        }) {
            return PlaylistLookupResult(
                exactMatch: exact,
                closestMatchName: nil,
                availableNames: availableNames
            )
        }

        let closest = bestFuzzyMatchName(for: name, in: availableNames)
        return PlaylistLookupResult(
            exactMatch: nil,
            closestMatchName: closest,
            availableNames: availableNames
        )
    }

    static func createPlaylist(named name: String, with song: Song?) async throws -> Playlist {
#if os(macOS)
        throw SkillError.executionFailed("Creating playlists isn't supported on macOS in this build.")
#else
        if let song = song {
            return try await MusicLibrary.shared.createPlaylist(
                name: name,
                description: nil,
                authorDisplayName: nil,
                items: [song]
            )
        }

        return try await MusicLibrary.shared.createPlaylist(
            name: name,
            description: nil,
            authorDisplayName: nil,
            items: [Song]()
        )
#endif
    }

    static func addSong(_ song: Song, to playlist: Playlist) async throws {
#if os(macOS)
        throw SkillError.executionFailed("Adding songs to playlists isn't supported on macOS in this build.")
#else
        try await MusicLibrary.shared.add(song, to: playlist)
#endif
    }

    static func loadAlbumTracks(_ album: Album) async throws -> [Track] {
        let detailed = try await album.with([.tracks])
        return Array(detailed.tracks ?? [])
    }

    static func loadPlaylistTracks(_ playlist: Playlist) async throws -> [Track] {
        let detailed = try await playlist.with([.tracks])
        return Array(detailed.tracks ?? [])
    }

    // MARK: - String Matching

    private static func bestFuzzyMatchName(for target: String, in options: [String]) -> String? {
        guard !options.isEmpty else { return nil }
        let normalizedTarget = normalizeString(target)
        var bestOption: String?
        var bestScore = -Double.infinity

        for option in options {
            let normalizedOption = normalizeString(option)
            let score = similarityScore(normalizedTarget, normalizedOption)
            if score > bestScore {
                bestScore = score
                bestOption = option
            }
        }
        return bestOption
    }

    private static func normalizeString(_ string: String) -> String {
        let lowered = string.lowercased()
        let allowed = CharacterSet.alphanumerics.union(.whitespaces)
        let filtered = lowered.unicodeScalars.filter { allowed.contains($0) }
        let collapsed = String(filtered)
            .split(separator: " ")
            .joined(separator: " ")
        return collapsed.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func similarityScore(_ lhs: String, _ rhs: String) -> Double {
        let lhsChars = Array(lhs)
        let rhsChars = Array(rhs)
        let lhsCount = lhsChars.count
        let rhsCount = rhsChars.count

        if lhsCount == 0 && rhsCount == 0 { return 1.0 }
        if lhsCount == 0 || rhsCount == 0 { return 0.0 }

        var distances = Array(repeating: Array(repeating: 0, count: rhsCount + 1), count: lhsCount + 1)

        for i in 0...lhsCount { distances[i][0] = i }
        for j in 0...rhsCount { distances[0][j] = j }

        for i in 1...lhsCount {
            for j in 1...rhsCount {
                let cost = lhsChars[i - 1] == rhsChars[j - 1] ? 0 : 1
                distances[i][j] = min(
                    distances[i - 1][j] + 1,
                    distances[i][j - 1] + 1,
                    distances[i - 1][j - 1] + cost
                )
            }
        }

        let distance = distances[lhsCount][rhsCount]
        let maxLen = max(lhsCount, rhsCount)
        return 1.0 - (Double(distance) / Double(maxLen))
    }
}
