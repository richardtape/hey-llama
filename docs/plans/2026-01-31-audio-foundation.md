# Milestone 1: Audio Foundation Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement continuous audio capture with VAD, showing visual state feedback when speech is detected/ends.

**Architecture:** AudioEngine captures 16kHz mono audio, publishes 30ms chunks via Combine. VADService (Silero VAD) detects speech start/end. AudioBuffer stores 15 seconds rolling audio. AssistantCoordinator orchestrates state transitions. AppState bridges coordinator to SwiftUI.

**Tech Stack:** Swift 5.9+, SwiftUI, AVFoundation (AVAudioEngine), FluidAudio (Silero VAD), Combine

**Reference Docs:**
- `docs/spec.md` - Section 6: Audio Pipeline (lines 888-1113)
- `docs/milestones/01-audio-foundation.md` - Task checklist

---

## Task 1: AssistantState Enum

**Files:**
- Create: `HeyLlama/Core/AssistantState.swift`
- Test: `HeyLlamaTests/AssistantStateTests.swift`

**Step 1: Create test file with failing tests**

Create `HeyLlamaTests/AssistantStateTests.swift`:

```swift
import XCTest
@testable import HeyLlama

final class AssistantStateTests: XCTestCase {

    func testIdleStatusIcon() {
        let state = AssistantState.idle
        XCTAssertEqual(state.statusIcon, "waveform.slash")
    }

    func testListeningStatusIcon() {
        let state = AssistantState.listening
        XCTAssertEqual(state.statusIcon, "waveform")
    }

    func testCapturingStatusIcon() {
        let state = AssistantState.capturing
        XCTAssertEqual(state.statusIcon, "waveform.badge.mic")
    }

    func testProcessingStatusIcon() {
        let state = AssistantState.processing
        XCTAssertEqual(state.statusIcon, "brain")
    }

    func testRespondingStatusIcon() {
        let state = AssistantState.responding
        XCTAssertEqual(state.statusIcon, "speaker.wave.2")
    }

    func testErrorStatusIcon() {
        let state = AssistantState.error("Test error")
        XCTAssertEqual(state.statusIcon, "exclamationmark.triangle")
    }

    func testIdleStatusText() {
        let state = AssistantState.idle
        XCTAssertEqual(state.statusText, "Idle")
    }

    func testListeningStatusText() {
        let state = AssistantState.listening
        XCTAssertEqual(state.statusText, "Listening...")
    }

    func testCapturingStatusText() {
        let state = AssistantState.capturing
        XCTAssertEqual(state.statusText, "Capturing...")
    }

    func testProcessingStatusText() {
        let state = AssistantState.processing
        XCTAssertEqual(state.statusText, "Processing...")
    }

    func testRespondingStatusText() {
        let state = AssistantState.responding
        XCTAssertEqual(state.statusText, "Speaking...")
    }

    func testErrorStatusTextIncludesMessage() {
        let state = AssistantState.error("Microphone unavailable")
        XCTAssertEqual(state.statusText, "Error: Microphone unavailable")
    }

    func testEquatableForSameCase() {
        XCTAssertEqual(AssistantState.idle, AssistantState.idle)
        XCTAssertEqual(AssistantState.listening, AssistantState.listening)
    }

    func testEquatableForDifferentCases() {
        XCTAssertNotEqual(AssistantState.idle, AssistantState.listening)
    }

    func testEquatableForErrorWithSameMessage() {
        XCTAssertEqual(AssistantState.error("Test"), AssistantState.error("Test"))
    }

    func testEquatableForErrorWithDifferentMessage() {
        XCTAssertNotEqual(AssistantState.error("A"), AssistantState.error("B"))
    }
}
```

**Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project HeyLlama.xcodeproj -scheme HeyLlama -only-testing:HeyLlamaTests/AssistantStateTests 2>&1 | tail -20`

Expected: Compilation error - `AssistantState` not found

**Step 3: Implement AssistantState**

Create `HeyLlama/Core/AssistantState.swift`:

```swift
import Foundation

enum AssistantState: Equatable {
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
```

**Step 4: Run tests to verify they pass**

Run: `xcodebuild test -project HeyLlama.xcodeproj -scheme HeyLlama -only-testing:HeyLlamaTests/AssistantStateTests 2>&1 | tail -20`

Expected: All tests pass

**Step 5: Commit**

```bash
git add HeyLlama/Core/AssistantState.swift HeyLlamaTests/AssistantStateTests.swift
git commit -m "feat(core): add AssistantState enum with status icons and text"
```

---

## Task 2: AudioChunk and AudioSource Models

**Files:**
- Create: `HeyLlama/Models/AudioChunk.swift`
- Test: `HeyLlamaTests/AudioChunkTests.swift`

**Step 1: Create test file with failing tests**

Create `HeyLlamaTests/AudioChunkTests.swift`:

```swift
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
```

**Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project HeyLlama.xcodeproj -scheme HeyLlama -only-testing:HeyLlamaTests/AudioChunkTests 2>&1 | tail -20`

Expected: Compilation error - `AudioChunk` and `AudioSource` not found

**Step 3: Implement AudioChunk and AudioSource**

Create `HeyLlama/Models/AudioChunk.swift`:

```swift
import AVFoundation

enum AudioSource: Equatable, Hashable {
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

struct AudioChunk {
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
```

**Step 4: Run tests to verify they pass**

Run: `xcodebuild test -project HeyLlama.xcodeproj -scheme HeyLlama -only-testing:HeyLlamaTests/AudioChunkTests 2>&1 | tail -20`

Expected: All tests pass

**Step 5: Commit**

```bash
git add HeyLlama/Models/AudioChunk.swift HeyLlamaTests/AudioChunkTests.swift
git commit -m "feat(models): add AudioChunk and AudioSource types"
```

---

## Task 3: AudioBuffer

**Files:**
- Create: `HeyLlama/Services/Audio/AudioBuffer.swift`
- Test: `HeyLlamaTests/AudioBufferTests.swift`

**Step 1: Create test file with failing tests**

Create `HeyLlamaTests/AudioBufferTests.swift`:

```swift
import XCTest
@testable import HeyLlama

final class AudioBufferTests: XCTestCase {

    func testAppendAddsToBuffer() {
        let buffer = AudioBuffer(maxSeconds: 15)
        let chunk = AudioChunk(samples: [0.1, 0.2, 0.3])

        buffer.append(chunk)

        XCTAssertEqual(buffer.sampleCount, 3)
    }

    func testAppendMultipleChunks() {
        let buffer = AudioBuffer(maxSeconds: 15)

        buffer.append(AudioChunk(samples: [0.1, 0.2]))
        buffer.append(AudioChunk(samples: [0.3, 0.4, 0.5]))

        XCTAssertEqual(buffer.sampleCount, 5)
    }

    func testBufferTrimsWhenExceedsMax() {
        // 1 second buffer at 16kHz = 16000 samples max
        let buffer = AudioBuffer(maxSeconds: 1)

        // Add 20000 samples (exceeds 16000 max)
        let samples = [Float](repeating: 0.5, count: 20000)
        buffer.append(AudioChunk(samples: samples))

        XCTAssertEqual(buffer.sampleCount, 16000)
    }

    func testMarkSpeechStartSetsIndex() {
        let buffer = AudioBuffer(maxSeconds: 15)

        // Add 8000 samples (0.5 seconds)
        buffer.append(AudioChunk(samples: [Float](repeating: 0.1, count: 8000)))

        buffer.markSpeechStart()

        // Should have marked speech start
        XCTAssertTrue(buffer.hasSpeechStart)
    }

    func testMarkSpeechStartWithLookback() {
        let buffer = AudioBuffer(maxSeconds: 15)

        // Add 8000 samples (0.5 seconds)
        let samples = (0..<8000).map { Float($0) / 8000.0 }
        buffer.append(AudioChunk(samples: samples))

        buffer.markSpeechStart()

        // Get utterance - should include 300ms lookback (4800 samples)
        let utterance = buffer.getUtteranceSinceSpeechStart()

        // Should get samples from (8000 - 4800) = 3200 to end
        XCTAssertEqual(utterance.samples.count, 4800)
    }

    func testGetUtteranceReturnsSamplesFromSpeechStart() {
        let buffer = AudioBuffer(maxSeconds: 15)

        // Add initial samples
        buffer.append(AudioChunk(samples: [Float](repeating: 0.0, count: 8000)))

        // Mark speech start
        buffer.markSpeechStart()

        // Add more samples (the actual speech)
        buffer.append(AudioChunk(samples: [Float](repeating: 1.0, count: 4000)))

        let utterance = buffer.getUtteranceSinceSpeechStart()

        // Should get: 4800 (lookback from mark) + 4000 (new samples) = 8800
        XCTAssertEqual(utterance.samples.count, 8800)
    }

    func testGetUtteranceResetsSpeechStartIndex() {
        let buffer = AudioBuffer(maxSeconds: 15)

        buffer.append(AudioChunk(samples: [Float](repeating: 0.1, count: 8000)))
        buffer.markSpeechStart()

        _ = buffer.getUtteranceSinceSpeechStart()

        XCTAssertFalse(buffer.hasSpeechStart)
    }

    func testGetUtteranceWithoutMarkReturnsAllSamples() {
        let buffer = AudioBuffer(maxSeconds: 15)

        buffer.append(AudioChunk(samples: [Float](repeating: 0.1, count: 1000)))

        let utterance = buffer.getUtteranceSinceSpeechStart()

        XCTAssertEqual(utterance.samples.count, 1000)
    }

    func testClearEmptiesBuffer() {
        let buffer = AudioBuffer(maxSeconds: 15)

        buffer.append(AudioChunk(samples: [Float](repeating: 0.1, count: 5000)))
        buffer.markSpeechStart()
        buffer.clear()

        XCTAssertEqual(buffer.sampleCount, 0)
        XCTAssertFalse(buffer.hasSpeechStart)
    }

    func testTrimmingAdjustsSpeechStartIndex() {
        // 1 second buffer = 16000 samples
        let buffer = AudioBuffer(maxSeconds: 1)

        // Add 10000 samples
        buffer.append(AudioChunk(samples: [Float](repeating: 0.1, count: 10000)))

        // Mark speech start (will be at ~5200 after lookback)
        buffer.markSpeechStart()

        // Add 10000 more samples - will trigger trimming
        buffer.append(AudioChunk(samples: [Float](repeating: 0.2, count: 10000)))

        // Buffer should be trimmed, speech start index adjusted
        XCTAssertEqual(buffer.sampleCount, 16000)

        // Speech start should still be valid (adjusted for trimming)
        let utterance = buffer.getUtteranceSinceSpeechStart()
        XCTAssertGreaterThan(utterance.samples.count, 0)
    }

    func testThreadSafety() {
        let buffer = AudioBuffer(maxSeconds: 15)
        let expectation = XCTestExpectation(description: "Concurrent access")
        expectation.expectedFulfillmentCount = 100

        for _ in 0..<100 {
            DispatchQueue.global().async {
                buffer.append(AudioChunk(samples: [Float](repeating: 0.1, count: 100)))
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 5.0)

        // Should have 10000 samples total
        XCTAssertEqual(buffer.sampleCount, 10000)
    }
}
```

**Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project HeyLlama.xcodeproj -scheme HeyLlama -only-testing:HeyLlamaTests/AudioBufferTests 2>&1 | tail -20`

Expected: Compilation error - `AudioBuffer` not found

**Step 3: Implement AudioBuffer**

Create `HeyLlama/Services/Audio/AudioBuffer.swift`:

```swift
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
```

**Step 4: Run tests to verify they pass**

Run: `xcodebuild test -project HeyLlama.xcodeproj -scheme HeyLlama -only-testing:HeyLlamaTests/AudioBufferTests 2>&1 | tail -20`

Expected: All tests pass

**Step 5: Commit**

```bash
git add HeyLlama/Services/Audio/AudioBuffer.swift HeyLlamaTests/AudioBufferTests.swift
git commit -m "feat(audio): add AudioBuffer with rolling 15-second storage"
```

---

## Task 4: VADService

**Files:**
- Create: `HeyLlama/Services/Audio/VADService.swift`
- Test: `HeyLlamaTests/VADServiceTests.swift`
- Create: `HeyLlamaTests/Mocks/MockSileroVAD.swift`

**Step 1: Create mock and test file**

Create `HeyLlamaTests/Mocks/MockSileroVAD.swift`:

```swift
import Foundation
@testable import HeyLlama

/// Mock VAD for testing - returns configurable probabilities
final class MockVADProcessor: VADProcessorProtocol {
    var probabilitiesToReturn: [Float] = []
    private var callIndex = 0

    func process(_ samples: [Float]) -> Float {
        guard callIndex < probabilitiesToReturn.count else {
            return 0.0
        }
        let probability = probabilitiesToReturn[callIndex]
        callIndex += 1
        return probability
    }

    func reset() {
        callIndex = 0
    }
}
```

Create `HeyLlamaTests/VADServiceTests.swift`:

```swift
import XCTest
@testable import HeyLlama

final class VADServiceTests: XCTestCase {

    func testReturnsSilenceWhenNoSpeechDetected() {
        let mockVAD = MockVADProcessor()
        mockVAD.probabilitiesToReturn = [0.1, 0.2, 0.1]
        let service = VADService(vadProcessor: mockVAD)

        let chunk = AudioChunk(samples: [Float](repeating: 0.0, count: 480))

        XCTAssertEqual(service.process(chunk), .silence)
        XCTAssertEqual(service.process(chunk), .silence)
        XCTAssertEqual(service.process(chunk), .silence)
    }

    func testReturnsSpeechStartOnFirstSpeechDetection() {
        let mockVAD = MockVADProcessor()
        mockVAD.probabilitiesToReturn = [0.1, 0.8] // silence, then speech
        let service = VADService(vadProcessor: mockVAD)

        let chunk = AudioChunk(samples: [Float](repeating: 0.0, count: 480))

        XCTAssertEqual(service.process(chunk), .silence)
        XCTAssertEqual(service.process(chunk), .speechStart)
    }

    func testReturnsSpeechContinueDuringOngoingSpeech() {
        let mockVAD = MockVADProcessor()
        mockVAD.probabilitiesToReturn = [0.8, 0.9, 0.85] // all speech
        let service = VADService(vadProcessor: mockVAD)

        let chunk = AudioChunk(samples: [Float](repeating: 0.0, count: 480))

        XCTAssertEqual(service.process(chunk), .speechStart)
        XCTAssertEqual(service.process(chunk), .speechContinue)
        XCTAssertEqual(service.process(chunk), .speechContinue)
    }

    func testReturnsSpeechEndAfterSilenceThresholdExceeded() {
        let mockVAD = MockVADProcessor()
        // Speech, then 10 frames of silence (threshold)
        var probs: [Float] = [0.8] // speech start
        probs.append(contentsOf: [Float](repeating: 0.1, count: 10)) // silence frames
        mockVAD.probabilitiesToReturn = probs
        let service = VADService(vadProcessor: mockVAD)

        let chunk = AudioChunk(samples: [Float](repeating: 0.0, count: 480))

        XCTAssertEqual(service.process(chunk), .speechStart)

        // 9 silence frames should return speechContinue
        for _ in 0..<9 {
            XCTAssertEqual(service.process(chunk), .speechContinue)
        }

        // 10th silence frame should return speechEnd
        XCTAssertEqual(service.process(chunk), .speechEnd)
    }

    func testBriefPausesReturnSpeechContinue() {
        let mockVAD = MockVADProcessor()
        // Speech, 5 silence frames (under threshold), then speech again
        var probs: [Float] = [0.8] // speech start
        probs.append(contentsOf: [Float](repeating: 0.1, count: 5)) // brief pause
        probs.append(0.8) // speech resumes
        mockVAD.probabilitiesToReturn = probs
        let service = VADService(vadProcessor: mockVAD)

        let chunk = AudioChunk(samples: [Float](repeating: 0.0, count: 480))

        XCTAssertEqual(service.process(chunk), .speechStart)

        // 5 silence frames should all return speechContinue
        for _ in 0..<5 {
            XCTAssertEqual(service.process(chunk), .speechContinue)
        }

        // Speech resumes - should still be speechContinue (not a new start)
        XCTAssertEqual(service.process(chunk), .speechContinue)
    }

    func testResetClearsInternalState() {
        let mockVAD = MockVADProcessor()
        mockVAD.probabilitiesToReturn = [0.8, 0.9, 0.8] // all speech
        let service = VADService(vadProcessor: mockVAD)

        let chunk = AudioChunk(samples: [Float](repeating: 0.0, count: 480))

        XCTAssertEqual(service.process(chunk), .speechStart)
        XCTAssertEqual(service.process(chunk), .speechContinue)

        service.reset()
        mockVAD.reset()

        // After reset, next speech should be a new speechStart
        XCTAssertEqual(service.process(chunk), .speechStart)
    }

    func testThresholdIsFiftyPercent() {
        let mockVAD = MockVADProcessor()
        mockVAD.probabilitiesToReturn = [0.49, 0.50, 0.51]
        let service = VADService(vadProcessor: mockVAD)

        let chunk = AudioChunk(samples: [Float](repeating: 0.0, count: 480))

        XCTAssertEqual(service.process(chunk), .silence) // 0.49 < 0.5
        XCTAssertEqual(service.process(chunk), .silence) // 0.50 not > 0.5
        XCTAssertEqual(service.process(chunk), .speechStart) // 0.51 > 0.5
    }
}
```

**Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project HeyLlama.xcodeproj -scheme HeyLlama -only-testing:HeyLlamaTests/VADServiceTests 2>&1 | tail -20`

Expected: Compilation error - `VADService` not found

**Step 3: Implement VADService**

Create `HeyLlama/Services/Audio/VADService.swift`:

```swift
import Foundation
import FluidAudio

/// Protocol for VAD processor to enable testing
protocol VADProcessorProtocol {
    func process(_ samples: [Float]) -> Float
}

/// Wrapper around FluidAudio's SileroVAD
final class SileroVADProcessor: VADProcessorProtocol {
    private let vad: SileroVAD

    init() {
        vad = SileroVAD()
    }

    func process(_ samples: [Float]) -> Float {
        vad.process(samples)
    }
}

enum VADResult: Equatable {
    case silence
    case speechStart
    case speechContinue
    case speechEnd
}

final class VADService {
    private let vadProcessor: VADProcessorProtocol
    private var speechActive = false
    private var silenceFrames = 0
    private let silenceThreshold = 10 // ~300ms at 30ms per frame
    private let probabilityThreshold: Float = 0.5

    init(vadProcessor: VADProcessorProtocol? = nil) {
        self.vadProcessor = vadProcessor ?? SileroVADProcessor()
    }

    func process(_ chunk: AudioChunk) -> VADResult {
        let probability = vadProcessor.process(chunk.samples)
        let isSpeech = probability > probabilityThreshold

        if isSpeech {
            silenceFrames = 0

            if !speechActive {
                speechActive = true
                return .speechStart
            } else {
                return .speechContinue
            }
        } else {
            if speechActive {
                silenceFrames += 1

                if silenceFrames >= silenceThreshold {
                    speechActive = false
                    silenceFrames = 0
                    return .speechEnd
                } else {
                    return .speechContinue
                }
            } else {
                return .silence
            }
        }
    }

    func reset() {
        speechActive = false
        silenceFrames = 0
    }
}
```

**Step 4: Run tests to verify they pass**

Run: `xcodebuild test -project HeyLlama.xcodeproj -scheme HeyLlama -only-testing:HeyLlamaTests/VADServiceTests 2>&1 | tail -20`

Expected: All tests pass

**Step 5: Commit**

```bash
git add HeyLlama/Services/Audio/VADService.swift HeyLlamaTests/VADServiceTests.swift HeyLlamaTests/Mocks/MockSileroVAD.swift
git commit -m "feat(audio): add VADService with Silero VAD integration"
```

---

## Task 5: AudioEngine

**Files:**
- Create: `HeyLlama/Services/Audio/AudioEngine.swift`

**Note:** AudioEngine interacts with hardware (AVAudioEngine) and is difficult to unit test in isolation. We'll implement it and verify through integration testing in Task 8.

**Step 1: Implement AudioEngine**

Create `HeyLlama/Services/Audio/AudioEngine.swift`:

```swift
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
```

**Step 2: Commit**

```bash
git add HeyLlama/Services/Audio/AudioEngine.swift
git commit -m "feat(audio): add AudioEngine with 16kHz mono capture"
```

---

## Task 6: Permissions Utility

**Files:**
- Create: `HeyLlama/Utilities/Permissions.swift`

**Step 1: Implement Permissions utility**

Create `HeyLlama/Utilities/Permissions.swift`:

```swift
import AVFoundation
import AppKit

enum Permissions {

    enum MicrophoneStatus {
        case granted
        case denied
        case undetermined
    }

    static func checkMicrophoneStatus() -> MicrophoneStatus {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return .granted
        case .denied, .restricted:
            return .denied
        case .notDetermined:
            return .undetermined
        @unknown default:
            return .undetermined
        }
    }

    static func requestMicrophoneAccess() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .audio)
    }

    static func openSystemSettingsPrivacy() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
    }
}
```

**Step 2: Commit**

```bash
git add HeyLlama/Utilities/Permissions.swift
git commit -m "feat(utils): add Permissions utility for microphone access"
```

---

## Task 7: AssistantCoordinator

**Files:**
- Create: `HeyLlama/Core/AssistantCoordinator.swift`

**Step 1: Implement AssistantCoordinator**

Create `HeyLlama/Core/AssistantCoordinator.swift`:

```swift
import Foundation
import Combine

@MainActor
final class AssistantCoordinator: ObservableObject {
    @Published private(set) var state: AssistantState = .idle
    @Published private(set) var isListening: Bool = false
    @Published private(set) var audioLevel: Float = 0

    private let audioEngine: AudioEngine
    private let vadService: VADService
    private let audioBuffer: AudioBuffer
    private var cancellables = Set<AnyCancellable>()

    init() {
        self.audioEngine = AudioEngine()
        self.vadService = VADService()
        self.audioBuffer = AudioBuffer(maxSeconds: 15)

        setupBindings()
    }

    private func setupBindings() {
        audioEngine.audioChunkPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] chunk in
                self?.processAudioChunk(chunk)
            }
            .store(in: &cancellables)

        audioEngine.$audioLevel
            .receive(on: DispatchQueue.main)
            .assign(to: &$audioLevel)
    }

    func start() async {
        let granted = await Permissions.requestMicrophoneAccess()

        guard granted else {
            state = .error("Microphone access denied")
            return
        }

        audioEngine.start()
        isListening = true
        state = .listening
    }

    func shutdown() {
        audioEngine.stop()
        isListening = false
        state = .idle
        vadService.reset()
        audioBuffer.clear()
    }

    private func processAudioChunk(_ chunk: AudioChunk) {
        audioBuffer.append(chunk)

        let vadResult = vadService.process(chunk)

        switch (state, vadResult) {
        case (.listening, .speechStart):
            audioBuffer.markSpeechStart()
            state = .capturing

        case (.capturing, .speechContinue):
            break

        case (.capturing, .speechEnd):
            state = .processing
            let utterance = audioBuffer.getUtteranceSinceSpeechStart()

            // Log utterance duration for debugging
            print("Captured utterance: \(String(format: "%.2f", utterance.duration))s")

            // Placeholder: In Milestone 2, we'll send to STT
            // For now, return to listening after brief delay
            Task {
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
                state = .listening
            }

        default:
            break
        }
    }
}
```

**Step 2: Commit**

```bash
git add HeyLlama/Core/AssistantCoordinator.swift
git commit -m "feat(core): add AssistantCoordinator with VAD state machine"
```

---

## Task 8: AppState Container

**Files:**
- Create: `HeyLlama/App/AppState.swift`

**Step 1: Implement AppState**

Create `HeyLlama/App/AppState.swift`:

```swift
import Foundation
import Combine

@MainActor
final class AppState: ObservableObject {
    let coordinator: AssistantCoordinator

    @Published private(set) var statusIcon: String = "waveform.slash"
    @Published private(set) var statusText: String = "Idle"
    @Published private(set) var audioLevel: Float = 0

    private var cancellables = Set<AnyCancellable>()

    init() {
        coordinator = AssistantCoordinator()
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
    }

    func start() async {
        await coordinator.start()
    }

    func shutdown() {
        coordinator.shutdown()
    }
}
```

**Step 2: Commit**

```bash
git add HeyLlama/App/AppState.swift
git commit -m "feat(app): add AppState container bridging coordinator to UI"
```

---

## Task 9: Wire Up HeyLlamaApp

**Files:**
- Modify: `HeyLlama/App/HeyLlamaApp.swift`

**Step 1: Update HeyLlamaApp to use AppState**

Replace contents of `HeyLlama/App/HeyLlamaApp.swift`:

```swift
import SwiftUI

@main
struct HeyLlamaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(appState)
        } label: {
            Image(systemName: appState.statusIcon)
        }

        Settings {
            SettingsView()
                .environmentObject(appState)
        }

        Window("Speaker Enrollment", id: "enrollment") {
            EnrollmentView()
                .environmentObject(appState)
        }
    }
}
```

**Step 2: Commit**

```bash
git add HeyLlama/App/HeyLlamaApp.swift
git commit -m "feat(app): wire AppState into SwiftUI scenes"
```

---

## Task 10: Update AppDelegate

**Files:**
- Modify: `HeyLlama/App/AppDelegate.swift`

**Step 1: Update AppDelegate to start coordinator**

Replace contents of `HeyLlama/App/AppDelegate.swift`:

```swift
import AppKit
import AVFoundation

class AppDelegate: NSObject, NSApplicationDelegate {
    private var appState: AppState?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationWillTerminate(_ notification: Notification) {
        appState?.shutdown()
    }

    func setAppState(_ state: AppState) {
        self.appState = state
        Task {
            await state.start()
        }
    }
}
```

**Note:** We need to wire AppState to AppDelegate from HeyLlamaApp. Update `HeyLlamaApp.swift` with an onAppear:

Update `HeyLlama/App/HeyLlamaApp.swift` to add initialization:

```swift
import SwiftUI

@main
struct HeyLlamaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()

    init() {
        // AppState will be set after @StateObject is initialized
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(appState)
                .onAppear {
                    appDelegate.setAppState(appState)
                }
        } label: {
            Image(systemName: appState.statusIcon)
        }

        Settings {
            SettingsView()
                .environmentObject(appState)
        }

        Window("Speaker Enrollment", id: "enrollment") {
            EnrollmentView()
                .environmentObject(appState)
        }
    }
}
```

**Step 2: Commit**

```bash
git add HeyLlama/App/AppDelegate.swift HeyLlama/App/HeyLlamaApp.swift
git commit -m "feat(app): update AppDelegate to start coordinator on launch"
```

---

## Task 11: Update MenuBarView

**Files:**
- Modify: `HeyLlama/UI/MenuBar/MenuBarView.swift`

**Step 1: Update MenuBarView to show dynamic state**

Replace contents of `HeyLlama/UI/MenuBar/MenuBarView.swift`:

```swift
import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Hey Llama")
                .font(.headline)
            Text("v0.1.0")
                .font(.caption)
                .foregroundColor(.secondary)

            Divider()

            HStack {
                Image(systemName: appState.statusIcon)
                Text(appState.statusText)
            }
            .foregroundColor(statusColor)

            AudioLevelIndicator(level: appState.audioLevel)
                .frame(height: 4)

            Divider()

            SettingsLink {
                Text("Preferences...")
            }
            .keyboardShortcut(",", modifiers: .command)

            Divider()

            Button("Quit") {
                appState.shutdown()
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
        .padding(8)
        .frame(width: 200)
    }

    private var statusColor: Color {
        switch appState.statusText {
        case "Capturing...":
            return .green
        case "Processing...":
            return .orange
        case _ where appState.statusText.hasPrefix("Error"):
            return .red
        default:
            return .secondary
        }
    }
}

struct AudioLevelIndicator: View {
    let level: Float

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.gray.opacity(0.3))

                RoundedRectangle(cornerRadius: 2)
                    .fill(levelColor)
                    .frame(width: geometry.size.width * CGFloat(min(level * 10, 1.0)))
            }
        }
    }

    private var levelColor: Color {
        if level > 0.1 {
            return .green
        } else if level > 0.05 {
            return .yellow
        } else {
            return .gray
        }
    }
}

#Preview {
    MenuBarView()
        .environmentObject(AppState())
}
```

**Step 2: Commit**

```bash
git add HeyLlama/UI/MenuBar/MenuBarView.swift
git commit -m "feat(ui): update MenuBarView with dynamic state and audio level"
```

---

## Task 12: Run Full Test Suite

**Step 1: Run all tests**

Run: `xcodebuild test -project HeyLlama.xcodeproj -scheme HeyLlama 2>&1 | grep -E "(Test Case|passed|failed|error:)"`

Expected: All tests pass

**Step 2: Fix any failing tests**

If tests fail, debug and fix issues.

---

## Task 13: Manual Integration Testing

**Step 1: Build and run**

Run: `xcodebuild build -project HeyLlama.xcodeproj -scheme HeyLlama`

**Step 2: Manual testing checklist**

Test in Xcode by running the app:

- [ ] App launches and requests microphone permission
- [ ] Permission grant enables listening (menu bar icon changes to "waveform")
- [ ] Speaking changes icon to "waveform.badge.mic" (capturing)
- [ ] Stopping speech shows "brain" icon briefly (processing)
- [ ] Returns to "waveform" (listening) after processing
- [ ] Audio level indicator responds to sound
- [ ] Preferences window still opens
- [ ] Quit still terminates app cleanly

---

## Task 14: Final Commit

**Step 1: Create milestone commit**

```bash
git add .
git commit -m "$(cat <<'EOF'
Milestone 1: Audio foundation with VAD

- Implement AudioChunk and AudioSource models
- Implement AudioBuffer with rolling 15-second storage
- Integrate FluidAudio Silero VAD for speech detection
- Implement AudioEngine with 16kHz mono capture
- Create AssistantCoordinator with state machine
- Add Permissions utility for microphone access
- Update menu bar UI with dynamic state indicators
- Add audio level indicator component
- Add unit tests for AudioBuffer, VADService, AssistantState

EOF
)"
```

---

## Summary

This plan implements Milestone 1 in 14 tasks:

1. **AssistantState** - State enum with icons and text
2. **AudioChunk/AudioSource** - Audio data models
3. **AudioBuffer** - Rolling 15-second buffer with speech marking
4. **VADService** - Silero VAD integration with speech detection
5. **AudioEngine** - AVAudioEngine wrapper for 16kHz capture
6. **Permissions** - Microphone access utility
7. **AssistantCoordinator** - Central orchestrator with state machine
8. **AppState** - Container bridging coordinator to SwiftUI
9. **HeyLlamaApp** - Wire up AppState
10. **AppDelegate** - Start coordinator on launch
11. **MenuBarView** - Dynamic state display with audio level
12. **Test Suite** - Run all tests
13. **Manual Testing** - Integration verification
14. **Final Commit** - Milestone commit

**Deliverable:** App that shows "Capturing..." when you speak and "Listening..." when silent. Menu bar icon reflects current state. Audio is captured and buffered but not yet transcribed.
