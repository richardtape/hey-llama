import Foundation

enum AssistantState: Equatable, Sendable {
    case idle
    case listening
    case capturing
    case processing
    case responding
    case error(String)

    var statusIcon: String {
        switch self {
        case .idle: return "waveform.slash"
        case .listening: return "waveform"
        case .capturing: return "waveform.badge.mic"
        case .processing: return "brain"
        case .responding: return "speaker.wave.2"
        case .error: return "exclamationmark.triangle"
        }
    }

    var statusText: String {
        switch self {
        case .idle: return "Idle"
        case .listening: return "Listening..."
        case .capturing: return "Capturing..."
        case .processing: return "Processing..."
        case .responding: return "Speaking..."
        case .error(let message): return "Error: \(message)"
        }
    }
}
