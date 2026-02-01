import AVFoundation
import Combine

final class AudioEngine: ObservableObject {
    private let engine = AVAudioEngine()
    private let sampleRate: Double = 16000
    private let chunkSize: AVAudioFrameCount = 480 // 30ms at 16kHz

    let audioChunkPublisher = PassthroughSubject<AudioChunk, Never>()

    @Published private(set) var isRunning = false
    @Published private(set) var audioLevel: Float = 0

    func start() {
        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        guard let outputFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: 1,
            interleaved: false
        ) else {
            print("Failed to create output format")
            return
        }

        guard let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
            print("Failed to create audio converter")
            return
        }

        inputNode.installTap(
            onBus: 0,
            bufferSize: chunkSize,
            format: inputFormat
        ) { [weak self] buffer, _ in
            self?.processBuffer(buffer, converter: converter, outputFormat: outputFormat)
        }

        do {
            try engine.start()
            isRunning = true
        } catch {
            print("Failed to start audio engine: \(error)")
        }
    }

    func stop() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRunning = false
    }

    private func processBuffer(
        _ buffer: AVAudioPCMBuffer,
        converter: AVAudioConverter,
        outputFormat: AVAudioFormat
    ) {
        let frameCapacity = AVAudioFrameCount(
            Double(buffer.frameLength) * sampleRate / buffer.format.sampleRate
        )

        guard let convertedBuffer = AVAudioPCMBuffer(
            pcmFormat: outputFormat,
            frameCapacity: frameCapacity
        ) else { return }

        var error: NSError?
        converter.convert(to: convertedBuffer, error: &error) { _, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }

        let chunk = AudioChunk(buffer: convertedBuffer)
        audioChunkPublisher.send(chunk)

        updateAudioLevel(convertedBuffer)
    }

    private func updateAudioLevel(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameLength = Int(buffer.frameLength)

        var sum: Float = 0
        for i in 0..<frameLength {
            sum += abs(channelData[i])
        }

        let average = sum / Float(frameLength)

        DispatchQueue.main.async {
            self.audioLevel = average
        }
    }
}
