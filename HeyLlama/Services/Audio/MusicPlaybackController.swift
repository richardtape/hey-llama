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
    private var lastReportedTitle: String = ""
    private var lastQueuedTitle: String = ""
    private var lastQueuedArtist: String = ""
    private var queuedItems: [(title: String, artist: String)] = []
    private var queuedIndex: Int = 0
    private var queuedSource: QueuedSource?

    var hasQueuedItems: Bool {
        !queuedItems.isEmpty
    }

    private init() {
        startPolling()
    }

    func playQueue(_ tracks: [Track]) async throws {
        guard !tracks.isEmpty else { return }
        queuedSource = .tracks(tracks)
        queuedItems = tracks.map { ($0.title, $0.artistName) }
        queuedIndex = 0
        setQueuedFallback()
        player.queue = ApplicationMusicPlayer.Queue(for: tracks)
        try await player.play()
        await refreshNowPlaying()
        await refreshNowPlayingAfterDelay()
    }

    func playSong(_ song: Song) async throws {
        queuedSource = .songs([song])
        queuedItems = [(song.title, song.artistName)]
        queuedIndex = 0
        setQueuedFallback()
        player.queue = ApplicationMusicPlayer.Queue(for: [song])
        try await player.play()
        await refreshNowPlaying()
        await refreshNowPlayingAfterDelay()
    }

    func playSongs(_ songs: [Song]) async throws {
        guard !songs.isEmpty else { return }
        queuedSource = .songs(songs)
        queuedItems = songs.map { ($0.title, $0.artistName) }
        queuedIndex = 0
        setQueuedFallback()
        player.queue = ApplicationMusicPlayer.Queue(for: songs)
        try await player.play()
        await refreshNowPlaying()
        await refreshNowPlayingAfterDelay()
    }

    func play() async throws {
        try await player.play()
        await refreshNowPlaying()
        await refreshNowPlayingAfterDelay()
    }

    func pause() async throws {
        player.pause()
        await refreshNowPlaying()
    }

    func next() async throws {
        try await player.skipToNextEntry()
        advanceQueueIndex(by: 1)
        await refreshNowPlaying()
        await refreshNowPlayingAfterDelay()
    }

    func previous() async throws {
        try await player.skipToPreviousEntry()
        advanceQueueIndex(by: -1)
        await refreshNowPlaying()
        await refreshNowPlayingAfterDelay()
    }

    func shuffleQueue() async throws -> Bool {
        guard let source = queuedSource else { return false }
        switch source {
        case .tracks(let tracks):
            let shuffled = tracks.shuffled()
            queuedSource = .tracks(shuffled)
            queuedItems = shuffled.map { ($0.title, $0.artistName) }
            queuedIndex = 0
            setQueuedFallback()
            player.queue = ApplicationMusicPlayer.Queue(for: shuffled)
            try await player.play()
        case .songs(let songs):
            let shuffled = songs.shuffled()
            queuedSource = .songs(shuffled)
            queuedItems = shuffled.map { ($0.title, $0.artistName) }
            queuedIndex = 0
            setQueuedFallback()
            player.queue = ApplicationMusicPlayer.Queue(for: shuffled)
            try await player.play()
        }
        await refreshNowPlaying()
        await refreshNowPlayingAfterDelay()
        return true
    }

    func refreshNowPlaying() async {
        let entry = player.queue.currentEntry ?? player.queue.entries.first
        if let song = entry?.item as? Song {
            nowPlayingTitle = song.title
            nowPlayingArtist = song.artistName
            nowPlayingAlbum = song.albumTitle ?? ""
        } else if let track = entry?.item as? Track {
            nowPlayingTitle = track.title
            nowPlayingArtist = track.artistName
            nowPlayingAlbum = track.albumTitle ?? ""
        } else if let playlist = entry?.item as? Playlist {
            nowPlayingTitle = playlist.name
            nowPlayingArtist = "Playlist"
            nowPlayingAlbum = ""
        } else if let album = entry?.item as? Album {
            nowPlayingTitle = album.title
            nowPlayingArtist = album.artistName
            nowPlayingAlbum = album.title
        } else {
            if !lastQueuedTitle.isEmpty {
                nowPlayingTitle = lastQueuedTitle
                nowPlayingArtist = lastQueuedArtist
                nowPlayingAlbum = ""
            } else {
                nowPlayingTitle = ""
                nowPlayingArtist = ""
                nowPlayingAlbum = ""
            }
        }

        isPlaying = player.state.playbackStatus == .playing

        if nowPlayingTitle != lastReportedTitle {
            lastReportedTitle = nowPlayingTitle
            let typeName = entry?.item.map { String(describing: type(of: $0)) } ?? "nil"
            print("[Music] Now playing update: title=\"\(nowPlayingTitle)\", artist=\"\(nowPlayingArtist)\", itemType=\(typeName)")
        } else if entry == nil {
            print("[Music] Now playing entry is nil; queue entries: \(player.queue.entries.count)")
        }
    }

    private func setQueuedFallback() {
        guard queuedIndex >= 0, queuedIndex < queuedItems.count else {
            lastQueuedTitle = ""
            lastQueuedArtist = ""
            return
        }
        let item = queuedItems[queuedIndex]
        lastQueuedTitle = item.title
        lastQueuedArtist = item.artist
    }

    private func advanceQueueIndex(by delta: Int) {
        guard !queuedItems.isEmpty else { return }
        let nextIndex = queuedIndex + delta
        if nextIndex < 0 {
            queuedIndex = 0
        } else if nextIndex >= queuedItems.count {
            queuedIndex = queuedItems.count - 1
        } else {
            queuedIndex = nextIndex
        }
        setQueuedFallback()
    }

    private enum QueuedSource {
        case tracks([Track])
        case songs([Song])
    }

    private func refreshNowPlayingAfterDelay() async {
        try? await Task.sleep(nanoseconds: 300_000_000)
        await refreshNowPlaying()
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
