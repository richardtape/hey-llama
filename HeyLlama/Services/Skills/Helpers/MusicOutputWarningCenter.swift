import Foundation

@MainActor
final class MusicOutputWarningCenter {
    static let shared = MusicOutputWarningCenter()

    private var didReportFailure = false

    private init() {}

    func failureMessage() -> String? {
        guard !didReportFailure else { return nil }
        didReportFailure = true
        return "I couldn't switch the system audio output to your preferred device."
    }
}
