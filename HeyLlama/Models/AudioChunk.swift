import AVFoundation

enum AudioSource: Equatable, Hashable, Sendable {
    case localMic
    case satellite(String)
    case iosApp(String)

    var identifier: String {
        switch self {
        case .localMic:
            return "local"
        case .satellite(let id):
            return "satellite-\(id)"
        case .iosApp(let id):
            return "ios-\(id)"
        }
    }
}

struct AudioChunk: Sendable {
    let samples: [Float]
    let sampleRate: Int
    let timestamp: Date
    let source: AudioSource

    var duration: TimeInterval {
        Double(samples.count) / Double(sampleRate)
    }

    init(samples: [Float], sampleRate: Int = 16000, source: AudioSource = .localMic) {
        self.samples = samples
        self.sampleRate = sampleRate
        self.timestamp = Date()
        self.source = source
    }

    init(buffer: AVAudioPCMBuffer, source: AudioSource = .localMic) {
        let frameLength = Int(buffer.frameLength)
        let channelData = buffer.floatChannelData![0]
        self.samples = Array(UnsafeBufferPointer(start: channelData, count: frameLength))
        self.sampleRate = Int(buffer.format.sampleRate)
        self.timestamp = Date()
        self.source = source
    }
}
