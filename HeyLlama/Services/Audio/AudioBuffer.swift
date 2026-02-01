import Foundation

final class AudioBuffer: @unchecked Sendable {
    private var buffer: [Float] = []
    private let maxSamples: Int
    private let sampleRate: Int = 16000
    private var speechStartIndex: Int?
    private let queue = DispatchQueue(label: "com.heyllama.audiobuffer", attributes: .concurrent)

    /// Number of samples for 300ms lookback
    private var lookbackSamples: Int {
        Int(0.3 * Double(sampleRate))
    }

    var sampleCount: Int {
        queue.sync {
            buffer.count
        }
    }

    var hasSpeechStart: Bool {
        queue.sync {
            speechStartIndex != nil
        }
    }

    init(maxSeconds: Int = 15) {
        self.maxSamples = maxSeconds * sampleRate
    }

    func append(_ chunk: AudioChunk) {
        queue.sync(flags: .barrier) {
            buffer.append(contentsOf: chunk.samples)

            if buffer.count > maxSamples {
                let excess = buffer.count - maxSamples
                buffer.removeFirst(excess)

                if let startIndex = speechStartIndex {
                    speechStartIndex = max(0, startIndex - excess)
                }
            }
        }
    }

    func markSpeechStart() {
        queue.sync(flags: .barrier) {
            speechStartIndex = max(0, buffer.count - lookbackSamples)
        }
    }

    func getUtteranceSinceSpeechStart() -> AudioChunk {
        queue.sync(flags: .barrier) {
            let startIndex = speechStartIndex ?? 0
            let samples = Array(buffer[startIndex...])

            speechStartIndex = nil

            return AudioChunk(samples: samples)
        }
    }

    func clear() {
        queue.sync(flags: .barrier) {
            buffer.removeAll()
            speechStartIndex = nil
        }
    }
}
