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

    private var cancellables = Set<AnyCancellable>()

    init(coordinator: AssistantCoordinator? = nil) {
        self.coordinator = coordinator ?? AssistantCoordinator()
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
    }

    func start() async {
        await coordinator.start()
    }

    func shutdown() {
        coordinator.shutdown()
    }
}
