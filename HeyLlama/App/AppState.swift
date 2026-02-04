import Foundation
import Combine

@MainActor
final class AppState: ObservableObject {
    let coordinator: AssistantCoordinator

    @Published private(set) var statusIcon: String = "waveform.slash"
    @Published private(set) var statusText: String = "Idle"
    @Published private(set) var audioLevel: Float = 0
    @Published private(set) var lastTranscription: String?
    @Published private(set) var lastCommand: String?
    @Published private(set) var lastResponse: String?
    @Published private(set) var isModelLoading: Bool = false
    @Published private(set) var currentSpeaker: Speaker?
    @Published private(set) var enrolledSpeakers: [Speaker] = []
    @Published private(set) var llmConfigured: Bool = false
    @Published var requiresOnboarding: Bool = true
    @Published var showOnboarding: Bool = false
    @Published private(set) var isListeningPaused: Bool = false
    @Published private(set) var musicNowPlayingTitle: String = ""
    @Published private(set) var musicNowPlayingArtist: String = ""
    @Published private(set) var musicIsPlaying: Bool = false
    @Published private(set) var musicPermissionStatus: Permissions.PermissionStatus = Permissions.checkMusicStatus()
    @Published private(set) var isMusicSkillEnabled: Bool = false

    private let musicPlaybackController = MusicPlaybackController.shared

    private var cancellables = Set<AnyCancellable>()

    init(coordinator: AssistantCoordinator? = nil) {
        self.coordinator = coordinator ?? AssistantCoordinator()
        self.requiresOnboarding = self.coordinator.requiresOnboarding
        setupBindings()
    }

    private func setupBindings() {
        coordinator.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.statusIcon = state.statusIcon
                self?.statusText = state.statusText
            }
            .store(in: &cancellables)

        coordinator.$audioLevel
            .receive(on: DispatchQueue.main)
            .assign(to: &$audioLevel)

        coordinator.$lastTranscription
            .receive(on: DispatchQueue.main)
            .assign(to: &$lastTranscription)

        coordinator.$lastCommand
            .receive(on: DispatchQueue.main)
            .assign(to: &$lastCommand)

        coordinator.$lastResponse
            .receive(on: DispatchQueue.main)
            .assign(to: &$lastResponse)

        coordinator.$isModelLoading
            .receive(on: DispatchQueue.main)
            .assign(to: &$isModelLoading)

        coordinator.$currentSpeaker
            .receive(on: DispatchQueue.main)
            .assign(to: &$currentSpeaker)

        coordinator.$enrolledSpeakers
            .receive(on: DispatchQueue.main)
            .assign(to: &$enrolledSpeakers)

        coordinator.$requiresOnboarding
            .receive(on: DispatchQueue.main)
            .assign(to: &$requiresOnboarding)

        coordinator.$llmConfigured
            .receive(on: DispatchQueue.main)
            .assign(to: &$llmConfigured)

        coordinator.$isListeningPaused
            .receive(on: DispatchQueue.main)
            .assign(to: &$isListeningPaused)

        coordinator.$musicPermissionStatus
            .receive(on: DispatchQueue.main)
            .assign(to: &$musicPermissionStatus)

        coordinator.$isMusicSkillEnabled
            .receive(on: DispatchQueue.main)
            .assign(to: &$isMusicSkillEnabled)

        musicPlaybackController.$nowPlayingTitle
            .receive(on: DispatchQueue.main)
            .assign(to: &$musicNowPlayingTitle)

        musicPlaybackController.$nowPlayingArtist
            .receive(on: DispatchQueue.main)
            .assign(to: &$musicNowPlayingArtist)

        musicPlaybackController.$isPlaying
            .receive(on: DispatchQueue.main)
            .assign(to: &$musicIsPlaying)
    }

    func checkAndShowOnboarding() {
        if coordinator.checkOnboardingRequired() {
            showOnboarding = true
        }
    }

    func completeOnboarding() {
        coordinator.completeOnboarding()
        showOnboarding = false
        requiresOnboarding = false
    }

    func start() async {
        guard !requiresOnboarding else {
            showOnboarding = true
            return
        }
        await coordinator.start()
    }

    func shutdown() {
        coordinator.shutdown()
    }

    /// Reload configuration after settings change
    func reloadConfig() async {
        await coordinator.reloadConfig()
    }

    var isMusicControlsVisible: Bool {
        isMusicSkillEnabled && musicPermissionStatus == .granted
    }

    func toggleListeningPaused(_ shouldPause: Bool) {
        if shouldPause {
            coordinator.pauseListening(reason: .manual)
        } else {
            coordinator.resumeListening(reason: .manual)
        }
    }

    func playPauseMusic() {
        Task { @MainActor in
            if musicIsPlaying {
                do {
                    try await musicPlaybackController.pause()
                    coordinator.resumeListening(reason: .autoPlayback)
                } catch {
                    print("Failed to pause music: \(error)")
                }
            } else {
                do {
                    _ = await MusicOutputSwitcher.attemptSwitchIfConfigured()
                    try await musicPlaybackController.play()
                    coordinator.pauseListening(reason: .autoPlayback)
                } catch {
                    print("Failed to play music: \(error)")
                }
            }
        }
    }

    func playNextTrack() {
        Task { @MainActor in
            do {
                try await musicPlaybackController.next()
            } catch {
                print("Failed to skip to next: \(error)")
            }
        }
    }

    func playPreviousTrack() {
        Task { @MainActor in
            do {
                try await musicPlaybackController.previous()
            } catch {
                print("Failed to skip to previous: \(error)")
            }
        }
    }
}
