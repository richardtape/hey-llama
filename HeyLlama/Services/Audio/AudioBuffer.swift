import Foundation

final class AudioBuffer {
    private var buffer: [Float] = []
    private let maxSamples: Int
    private let sampleRate: Int = 16000
    private var speechStartIndex: Int?
    private let lock = NSLock()

    /// Number of samples for 300ms lookback
    private var lookbackSamples: Int {
        Int(0.3 * Double(sampleRate))
    }

    var sampleCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return buffer.count
    }

    var hasSpeechStart: Bool {
        lock.lock()
        defer { lock.unlock() }
        return speechStartIndex != nil
    }

    init(maxSeconds: Int = 15) {
        self.maxSamples = maxSeconds * sampleRate
    }

    func append(_ chunk: AudioChunk) {
        lock.lock()
        defer { lock.unlock() }

        buffer.append(contentsOf: chunk.samples)

        if buffer.count > maxSamples {
            let excess = buffer.count - maxSamples
            buffer.removeFirst(excess)

            if let startIndex = speechStartIndex {
                speechStartIndex = max(0, startIndex - excess)
            }
        }
    }

    func markSpeechStart() {
        lock.lock()
        defer { lock.unlock() }

        speechStartIndex = max(0, buffer.count - lookbackSamples)
    }

    func getUtteranceSinceSpeechStart() -> AudioChunk {
        lock.lock()
        defer { lock.unlock() }

        let startIndex = speechStartIndex ?? 0
        let samples = Array(buffer[startIndex...])

        speechStartIndex = nil

        return AudioChunk(samples: samples)
    }

    func clear() {
        lock.lock()
        defer { lock.unlock() }

        buffer.removeAll()
        speechStartIndex = nil
    }
}
