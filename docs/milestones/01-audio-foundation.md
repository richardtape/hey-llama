# Milestone 1: Audio Foundation

## Overview

For general project context, see:
- [`CLAUDE.md`](../../CLAUDE.md) - Quick reference for architecture and patterns
- [`docs/spec.md`](../spec.md) - Complete technical specification (Section 6: Audio Pipeline)

## Goal

Implement continuous audio capture with Voice Activity Detection (VAD). The app should visually indicate when speech is detected and when the user stops speaking.

## Prerequisites

- Milestone 0 complete (project setup, dependencies configured)

---

## Phase 1: Design

Key design decisions for this milestone:

- [ ] Confirm audio format: 16kHz mono Float32 (required by ML models)
- [ ] Confirm chunk size: 480 samples (30ms at 16kHz)
- [ ] Confirm buffer duration: 15 seconds rolling buffer
- [ ] Confirm silence threshold: 300ms (10 frames) to detect speech end
- [ ] Confirm VAD probability threshold: 0.5

---

## Phase 2: Test Setup

### Create Test Infrastructure

- [ ] Create `AudioBufferTests.swift` in test target
- [ ] Create `VADServiceTests.swift` in test target
- [ ] Create `AssistantStateTests.swift` in test target

### Write AudioBuffer Tests (RED - these should fail initially)

```swift
// Tests to write before implementation:
func testAppendAddsToBuffer()
func testBufferTrimsWhenExceedsMax()
func testMarkSpeechStartSetsIndex()
func testGetUtteranceReturnsSamplesFromSpeechStart()
func testGetUtteranceResetsSpeechStartIndex()
func testClearEmptiesBuffer()
```

- [ ] Test: Appending chunks increases buffer size
- [ ] Test: Buffer trims oldest samples when exceeding max
- [ ] Test: `markSpeechStart()` records position with 300ms lookback
- [ ] Test: `getUtteranceSinceSpeechStart()` returns correct samples
- [ ] Test: `getUtteranceSinceSpeechStart()` resets state for next utterance
- [ ] Test: `clear()` empties buffer and resets state

### Write VADService Tests (RED)

- [ ] Test: Returns `.silence` when no speech detected
- [ ] Test: Returns `.speechStart` on first speech detection
- [ ] Test: Returns `.speechContinue` during ongoing speech
- [ ] Test: Returns `.speechEnd` after silence threshold exceeded
- [ ] Test: Brief pauses (< threshold) return `.speechContinue`
- [ ] Test: `reset()` clears internal state

### Write AssistantState Tests (RED)

- [ ] Test: Each state returns correct `statusIcon` SF Symbol
- [ ] Test: Each state returns correct `statusText` string
- [ ] Test: Error state includes error message in `statusText`

---

## Phase 3: Implementation

### Implement Models ⚡ (Parallelizable)

#### AudioChunk Model ⚡

- [ ] Create `AudioChunk.swift` in `Models/`
- [ ] Define `samples: [Float]` property for normalized audio data
- [ ] Define `sampleRate: Int` property (default 16000)
- [ ] Define `timestamp: Date` property
- [ ] Define `source: AudioSource` property
- [ ] Implement computed `duration: TimeInterval` property
- [ ] Implement initializer from `AVAudioPCMBuffer`

#### AudioSource Enum ⚡

- [ ] Create `AudioSource` enum (in `AudioChunk.swift` or separate file)
- [ ] Define `.localMic` case
- [ ] Define `.satellite(String)` case for client ID
- [ ] Define `.iosApp(String)` case for device ID
- [ ] Implement `identifier: String` computed property
- [ ] Conform to `Equatable`, `Hashable`

### Implement AssistantState

- [ ] Create `AssistantState.swift` in `Core/`
- [ ] Define enum with cases: `.idle`, `.listening`, `.capturing`, `.processing`, `.responding`, `.error(String)`
- [ ] Implement `statusIcon: String` computed property (SF Symbol names)
- [ ] Implement `statusText: String` computed property
- [ ] Conform to `Equatable`

### Implement AudioBuffer

- [ ] Create `AudioBuffer.swift` in `Services/Audio/`
- [ ] Define private `buffer: [Float]` array
- [ ] Define `maxSamples` based on duration (15 seconds × 16000)
- [ ] Define private `speechStartIndex: Int?`
- [ ] Use `NSLock` for thread safety

#### AudioBuffer Methods

- [ ] Implement `append(_ chunk: AudioChunk)` - add samples, trim if needed
- [ ] Implement `markSpeechStart()` - mark position with 300ms lookback
- [ ] Implement `getUtteranceSinceSpeechStart() -> AudioChunk` - extract and reset
- [ ] Implement `clear()` - empty buffer and reset state

### Implement VADService

- [ ] Create `VADService.swift` in `Services/Audio/`
- [ ] Import FluidAudio
- [ ] Create private `SileroVAD` instance
- [ ] Define `VADResult` enum: `.silence`, `.speechStart`, `.speechContinue`, `.speechEnd`
- [ ] Track `speechActive: Bool` state
- [ ] Track `silenceFrames: Int` counter
- [ ] Define `silenceThreshold = 10` (frames ≈ 300ms)

#### VADService Methods

- [ ] Implement `process(_ chunk: AudioChunk) -> VADResult`
- [ ] Implement `reset()` to clear internal state

### Implement AudioEngine

- [ ] Create `AudioEngine.swift` in `Services/Audio/`
- [ ] Make class conform to `ObservableObject`
- [ ] Create private `AVAudioEngine` instance
- [ ] Define `sampleRate: Double = 16000`
- [ ] Define `chunkSize: AVAudioFrameCount = 480`
- [ ] Create `audioChunkPublisher` as `PassthroughSubject<AudioChunk, Never>`
- [ ] Implement `@Published isRunning: Bool`
- [ ] Implement `@Published audioLevel: Float`

#### AudioEngine Methods

- [ ] Implement `start()` - install tap, start engine
- [ ] Implement `stop()` - remove tap, stop engine
- [ ] Implement private `processBuffer()` - convert format, publish chunk, update level

### Implement Permissions Utility

- [ ] Create `Permissions.swift` in `Utilities/`
- [ ] Implement `requestMicrophoneAccess() async -> Bool`
- [ ] Handle permission denied with guidance to System Settings

### Implement AssistantCoordinator Shell

- [ ] Create `AssistantCoordinator.swift` in `Core/`
- [ ] Make class `@MainActor` and conform to `ObservableObject`
- [ ] Create `@Published state: AssistantState = .idle`
- [ ] Create `@Published isListening: Bool = false`
- [ ] Create private `audioEngine: AudioEngine`
- [ ] Create private `vadService: VADService`
- [ ] Create private `audioBuffer: AudioBuffer`
- [ ] Create `cancellables: Set<AnyCancellable>`

#### Coordinator Pipeline

- [ ] Subscribe to `audioEngine.audioChunkPublisher` in init
- [ ] Append each chunk to buffer
- [ ] Process chunk through VAD
- [ ] On `.speechStart`: transition to `.capturing`, call `audioBuffer.markSpeechStart()`
- [ ] On `.speechEnd`: transition to `.processing`, extract utterance, log duration
- [ ] Return to `.listening` after processing (placeholder for STT in M2)

#### Coordinator Lifecycle

- [ ] Implement `start() async` - start audio engine, set states
- [ ] Implement `shutdown()` - stop audio engine, reset states

### Implement AppState Container

- [ ] Create `AppState.swift` in `App/`
- [ ] Make class conform to `ObservableObject`
- [ ] Hold reference to `AssistantCoordinator`
- [ ] Expose `statusIcon: String` delegating to coordinator state
- [ ] Initialize and start coordinator on app launch

---

## Phase 4: Integration

### Wire Up AppState

- [ ] Inject `AppState` as `@StateObject` in `HeyLlamaApp`
- [ ] Pass as `@EnvironmentObject` to views

### Update Menu Bar UI

- [ ] Display current state icon in menu bar using `appState.statusIcon`
- [ ] Display state text in dropdown
- [ ] Add audio level indicator showing live input level
- [ ] Show "Listening..." / "Capturing..." status dynamically

### Update AppDelegate

- [ ] Call permission request on launch
- [ ] Start coordinator after permissions granted
- [ ] Handle permission denied gracefully

---

## Phase 5: Verification

### Test Suite

- [ ] Run all unit tests in Xcode (`Cmd+U`)
- [ ] All AudioBuffer tests pass (GREEN)
- [ ] All VADService tests pass (GREEN)
- [ ] All AssistantState tests pass (GREEN)

### Manual Testing

- [ ] App launches and requests microphone permission
- [ ] Permission grant enables listening
- [ ] Permission deny shows helpful guidance
- [ ] Menu bar icon shows "waveform" when listening
- [ ] Speaking changes icon to "waveform.badge.mic" (capturing)
- [ ] Stopping speech triggers processing state briefly
- [ ] Returns to listening state after processing
- [ ] Audio level indicator responds to sound
- [ ] No crashes during extended operation (5+ minutes)
- [ ] No memory leaks (check Instruments)

### Regression Check

- [ ] All Milestone 0 functionality still works
- [ ] Preferences window still opens
- [ ] Quit still terminates app cleanly

---

## Phase 6: Completion

### Git Commit

```bash
git add .
git commit -m "Milestone 1: Audio foundation with VAD

- Implement AudioChunk and AudioSource models
- Implement AudioBuffer with rolling 15-second storage
- Integrate FluidAudio Silero VAD for speech detection
- Implement AudioEngine with 16kHz mono capture
- Create AssistantCoordinator with state machine
- Add microphone permission handling
- Update menu bar UI with state indicators
- Add unit tests for AudioBuffer, VADService, AssistantState"
```

### Ready for Next Milestone

- [ ] All Phase 5 verification items pass
- [ ] Code committed to version control
- [ ] Ready to proceed to [Milestone 2: Speech-to-Text](./02-speech-to-text.md)

---

## Deliverable

App that shows "Capturing..." when you speak and "Listening..." when silent. The menu bar icon reflects current state. Audio is captured and buffered but not yet transcribed.
