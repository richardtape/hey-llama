import XCTest
import AVFoundation
@testable import HeyLlama

final class AudioChunkTests: XCTestCase {

    // MARK: - AudioSource Tests

    func testLocalMicIdentifier() {
        let source = AudioSource.localMic
        XCTAssertEqual(source.identifier, "local")
    }

    func testSatelliteIdentifier() {
        let source = AudioSource.satellite("bedroom-pi")
        XCTAssertEqual(source.identifier, "satellite-bedroom-pi")
    }

    func testIOSAppIdentifier() {
        let source = AudioSource.iosApp("iphone-123")
        XCTAssertEqual(source.identifier, "ios-iphone-123")
    }

    func testAudioSourceEquatable() {
        XCTAssertEqual(AudioSource.localMic, AudioSource.localMic)
        XCTAssertEqual(AudioSource.satellite("a"), AudioSource.satellite("a"))
        XCTAssertNotEqual(AudioSource.satellite("a"), AudioSource.satellite("b"))
        XCTAssertNotEqual(AudioSource.localMic, AudioSource.satellite("a"))
    }

    func testAudioSourceHashable() {
        var set = Set<AudioSource>()
        set.insert(.localMic)
        set.insert(.satellite("a"))
        set.insert(.satellite("a")) // Duplicate
        XCTAssertEqual(set.count, 2)
    }

    // MARK: - AudioChunk Tests

    func testAudioChunkInitWithSamples() {
        let samples: [Float] = [0.1, 0.2, 0.3, 0.4, 0.5]
        let chunk = AudioChunk(samples: samples)

        XCTAssertEqual(chunk.samples, samples)
        XCTAssertEqual(chunk.sampleRate, 16000)
        XCTAssertEqual(chunk.source, .localMic)
    }

    func testAudioChunkInitWithCustomSampleRate() {
        let samples: [Float] = [0.1, 0.2]
        let chunk = AudioChunk(samples: samples, sampleRate: 44100)

        XCTAssertEqual(chunk.sampleRate, 44100)
    }

    func testAudioChunkInitWithCustomSource() {
        let samples: [Float] = [0.1]
        let chunk = AudioChunk(samples: samples, source: .satellite("test"))

        XCTAssertEqual(chunk.source, .satellite("test"))
    }

    func testAudioChunkDuration() {
        // 16000 samples at 16kHz = 1 second
        let samples = [Float](repeating: 0.0, count: 16000)
        let chunk = AudioChunk(samples: samples)

        XCTAssertEqual(chunk.duration, 1.0, accuracy: 0.001)
    }

    func testAudioChunkDuration30ms() {
        // 480 samples at 16kHz = 30ms
        let samples = [Float](repeating: 0.0, count: 480)
        let chunk = AudioChunk(samples: samples)

        XCTAssertEqual(chunk.duration, 0.03, accuracy: 0.001)
    }

    func testAudioChunkTimestampIsRecent() {
        let before = Date()
        let chunk = AudioChunk(samples: [0.1])
        let after = Date()

        XCTAssertGreaterThanOrEqual(chunk.timestamp, before)
        XCTAssertLessThanOrEqual(chunk.timestamp, after)
    }
}
