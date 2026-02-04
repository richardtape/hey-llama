import Foundation
import Combine
import MusicKit

@MainActor
final class MusicPlaybackController: ObservableObject {
    static let shared = MusicPlaybackController()

    @Published private(set) var nowPlayingTitle: String = ""
    @Published private(set) var nowPlayingArtist: String = ""
    @Published private(set) var nowPlayingAlbum: String = ""
    @Published private(set) var isPlaying: Bool = false

    private let player = ApplicationMusicPlayer.shared
    private var pollTask: Task<Void, Never>?

    private init() {
        startPolling()
    }

    func playQueue(_ tracks: [Track]) async throws {
        guard !tracks.isEmpty else { return }
        player.queue = ApplicationMusicPlayer.Queue(for: tracks)
        try await player.play()
        await refreshNowPlaying()
    }

    func playSong(_ song: Song) async throws {
        player.queue = ApplicationMusicPlayer.Queue(for: [song])
        try await player.play()
        await refreshNowPlaying()
    }

    func playSongs(_ songs: [Song]) async throws {
        guard !songs.isEmpty else { return }
        player.queue = ApplicationMusicPlayer.Queue(for: songs)
        try await player.play()
        await refreshNowPlaying()
    }

    func play() async throws {
        try await player.play()
        await refreshNowPlaying()
    }

    func pause() async throws {
        player.pause()
        await refreshNowPlaying()
    }

    func next() async throws {
        try await player.skipToNextEntry()
        await refreshNowPlaying()
    }

    func previous() async throws {
        try await player.skipToPreviousEntry()
        await refreshNowPlaying()
    }

    func refreshNowPlaying() async {
        let entry = player.queue.currentEntry
        if let song = entry?.item as? Song {
            nowPlayingTitle = song.title
            nowPlayingArtist = song.artistName
            nowPlayingAlbum = song.albumTitle ?? ""
        } else if let playlist = entry?.item as? Playlist {
            nowPlayingTitle = playlist.name
            nowPlayingArtist = "Playlist"
            nowPlayingAlbum = ""
        } else if let album = entry?.item as? Album {
            nowPlayingTitle = album.title
            nowPlayingArtist = album.artistName
            nowPlayingAlbum = album.title
        } else {
            nowPlayingTitle = ""
            nowPlayingArtist = ""
            nowPlayingAlbum = ""
        }

        isPlaying = player.state.playbackStatus == .playing
    }

    private func startPolling() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refreshNowPlaying()
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }
}
