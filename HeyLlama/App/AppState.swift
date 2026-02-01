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
    @Published private(set) var isModelLoading: Bool = false
    @Published private(set) var currentSpeaker: Speaker?
    @Published var requiresOnboarding: Bool = true
    @Published var showOnboarding: Bool = false

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

        coordinator.$isModelLoading
            .receive(on: DispatchQueue.main)
            .assign(to: &$isModelLoading)

        coordinator.$currentSpeaker
            .receive(on: DispatchQueue.main)
            .assign(to: &$currentSpeaker)

        coordinator.$requiresOnboarding
            .receive(on: DispatchQueue.main)
            .assign(to: &$requiresOnboarding)
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
}
