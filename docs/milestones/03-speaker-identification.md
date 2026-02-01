# Milestone 3: Speaker Identification

## Overview

For general project context, see:
- [`CLAUDE.md`](../../CLAUDE.md) - Quick reference for architecture and patterns
- [`docs/spec.md`](../spec.md) - Complete technical specification (Sections 3.3, 5.1)

## Goal

Implement speaker identification using FluidAudio embeddings. Users can enroll their voice, and the system identifies who is speaking when processing commands.

## Prerequisites

- Milestone 2 complete (STT and wake word detection working)

---

## Phase 1: Design

Key design decisions for this milestone:

- [ ] Confirm embedding dimensions: 256 or 512 (per FluidAudio model)
- [ ] Confirm distance threshold: 0.5 cosine distance for match
- [ ] Confirm enrollment samples: 3-5 voice samples per speaker
- [ ] Confirm embedding aggregation: average embeddings from samples
- [ ] Confirm unknown speaker handling: return `nil` (display as "Guest")

---

## Phase 2: Test Setup

### Create Test Infrastructure

- [ ] Create `SpeakerEmbeddingTests.swift` in test target
- [ ] Create `SpeakerServiceTests.swift` in test target
- [ ] Create `MockSpeakerService.swift` in `HeyLlamaTests/Mocks/`

### Write SpeakerEmbedding Tests (RED)

```swift
// Tests to write before implementation:
func testIdenticalVectorsHaveZeroDistance()
func testOrthogonalVectorsHaveMaxDistance()
func testMismatchedLengthsReturnMaxDistance()
func testPartialSimilarityReturnsExpectedDistance()
func testDistanceIsSymmetric()
```

- [ ] Test: Identical vectors `[1,0,0]` and `[1,0,0]` → distance 0.0
- [ ] Test: Orthogonal vectors `[1,0,0]` and `[0,1,0]` → distance 1.0
- [ ] Test: Mismatched lengths return 1.0 (max distance)
- [ ] Test: `[1,1,0]` and `[1,0,0]` → distance ~0.29 (1 - cos(45°))
- [ ] Test: `a.distance(to: b) == b.distance(to: a)`

### Write SpeakerService Tests (RED)

- [ ] Test: `identify()` returns `nil` when no speakers enrolled
- [ ] Test: `identify()` returns matching speaker below threshold
- [ ] Test: `identify()` returns `nil` when distance above threshold
- [ ] Test: `enroll()` creates speaker with averaged embedding
- [ ] Test: `remove()` deletes speaker from storage
- [ ] Test: Enrolled speakers persist across service reload

### Create MockSpeakerService

- [ ] Implement `SpeakerServiceProtocol`
- [ ] Allow setting `mockIdentifyResult: Speaker?`
- [ ] Track `identifyCalls: [AudioChunk]`
- [ ] Implement `enrolledSpeakers` as settable

---

## Phase 3: Implementation

### Implement Models ⚡ (Parallelizable)

#### SpeakerEmbedding Model ⚡

- [ ] Create `SpeakerEmbedding.swift` in `Services/Speaker/`
- [ ] Define `vector: [Float]` property (256 or 512 dimensions)
- [ ] Define `modelVersion: String` for compatibility
- [ ] Conform to `Codable`, `Equatable`

##### Embedding Distance Calculation

- [ ] Implement `distance(to other: SpeakerEmbedding) -> Float`
  - Calculate dot product
  - Calculate norms
  - Return `1 - cosineSimilarity`
  - Handle mismatched lengths (return 1.0)

#### Speaker Model ⚡

- [ ] Create `Speaker.swift` in `Models/`
- [ ] Define `id: UUID`
- [ ] Define `name: String`
- [ ] Define `enrolledAt: Date`
- [ ] Define `embedding: SpeakerEmbedding`
- [ ] Define `metadata: SpeakerMetadata`
- [ ] Conform to `Identifiable`, `Codable`, `Equatable`

#### SpeakerMetadata Model

- [ ] Create `SpeakerMetadata` struct in `Speaker.swift`
- [ ] Define `commandCount: Int = 0`
- [ ] Define `lastSeenAt: Date?`
- [ ] Define `preferredResponseMode: ResponseMode = .speaker`
- [ ] Conform to `Codable`, `Equatable`

### Define SpeakerServiceProtocol

- [ ] Create `SpeakerServiceProtocol.swift` in `Services/Speaker/`
- [ ] Define `func loadModel() async`
- [ ] Define `func identify(_ audio: AudioChunk) async -> Speaker?`
- [ ] Define `func enroll(name: String, samples: [AudioChunk]) async throws -> Speaker`
- [ ] Define `func remove(_ speaker: Speaker) async`
- [ ] Define `var enrolledSpeakers: [Speaker] { get }`
- [ ] Define `var isModelLoaded: Bool { get }`

### Implement SpeakerStore

- [ ] Create `SpeakerStore.swift` in `Storage/`
- [ ] Implement `loadSpeakers() -> [Speaker]`
- [ ] Implement `saveSpeakers(_ speakers: [Speaker]) throws`
- [ ] Store at `~/Library/Application Support/HeyLlama/speakers.json`
- [ ] Handle file not found (return empty array)

### Implement SpeakerService

- [ ] Create `SpeakerService.swift` in `Services/Speaker/`
- [ ] Import FluidAudio
- [ ] Conform to `SpeakerServiceProtocol`
- [ ] Create private FluidAudio speaker model
- [ ] Define `identificationThreshold: Float = 0.5`
- [ ] Store `enrolledSpeakers: [Speaker]` in memory

#### SpeakerService Methods

- [ ] Implement `loadModel() async`
  - Initialize FluidAudio embedding model
  - Load saved speakers from SpeakerStore
  - Handle errors gracefully

- [ ] Implement `identify(_ audio: AudioChunk) async -> Speaker?`
  - Extract embedding from audio
  - Compare against all enrolled speakers
  - Find minimum distance match
  - Return speaker if below threshold, else `nil`
  - Update `lastSeenAt` on match

- [ ] Implement `enroll(name: String, samples: [AudioChunk]) async throws -> Speaker`
  - Extract embedding from each sample
  - Average embeddings
  - Create Speaker with averaged embedding
  - Add to enrolled speakers
  - Save to SpeakerStore
  - Return created speaker

- [ ] Implement `remove(_ speaker: Speaker) async`
  - Remove from enrolled speakers
  - Save updated list to SpeakerStore

---

## Phase 4: Integration

### Add to Coordinator

- [ ] Add `speakerService: SpeakerServiceProtocol` to coordinator
- [ ] Accept optional protocol in init (for testing)
- [ ] Default to `SpeakerService()` if not provided
- [ ] Add `@Published currentSpeaker: Speaker?`

### Update Coordinator Start

- [ ] Call `speakerService.loadModel()` in `start()` method

### Update Utterance Processing for Parallel Execution

- [ ] Modify `processUtterance()` to run STT and speaker ID in parallel:
  ```swift
  async let transcriptionTask = sttService.transcribe(audio)
  async let speakerTask = speakerService.identify(audio)
  let (transcription, speaker) = await (transcriptionTask, speakerTask)
  ```
- [ ] Update `currentSpeaker` with identification result
- [ ] Include speaker in command context

### Add Coordinator Enrollment Methods

- [ ] Implement `enrollSpeaker(name: String, samples: [AudioChunk]) async throws -> Speaker`
- [ ] Implement `removeSpeaker(_ speaker: Speaker) async`

### Create Enrollment UI

#### EnrollmentPrompts

- [ ] Create `EnrollmentPrompts.swift` in `UI/Enrollment/`
- [ ] Define array of 5 phrases for enrollment:
  - "Hey Llama, what's the weather today?"
  - "Turn on the living room lights"
  - "My name is [name] and I'm enrolling my voice"
  - "Please set a timer for five minutes"
  - "Hey Llama, tell me a joke"

#### EnrollmentView

- [ ] Create `EnrollmentView.swift` in `UI/Enrollment/`
- [ ] Step 1: Text field for speaker name
- [ ] Step 2: Recording UI for voice samples
  - Show current phrase to speak
  - Show recording indicator
  - Show progress (1 of 5, etc.)
- [ ] Step 3: Confirmation with success message
- [ ] Handle errors with user-friendly messages
- [ ] Add cancel button

#### SpeakersSettingsView

- [ ] Create `SpeakersSettingsView.swift` in `UI/Settings/`
- [ ] List enrolled speakers with name and date
- [ ] Add "Enroll New Speaker..." button
- [ ] Add delete button per speaker (with confirmation)
- [ ] Show command count if available

### Update Menu Bar UI

- [ ] Display identified speaker name in dropdown
- [ ] Show "Guest" for unknown speakers
- [ ] Format: "Rich: what time is it" or "Guest: what time is it"
- [ ] Add "Enroll Speaker..." menu item

---

## Phase 5: Verification

### Test Suite

- [ ] Run all unit tests: `xcodebuild test -scheme HeyLlama`
- [ ] All SpeakerEmbedding tests pass (GREEN)
- [ ] All SpeakerService tests pass (GREEN)
- [ ] Previous milestone tests still pass

### Manual Testing

- [ ] Enroll yourself as first speaker
- [ ] Speak and verify your name appears
- [ ] Enroll second speaker (or have someone else)
- [ ] Verify correct identification for each speaker
- [ ] Speak as unknown person: shows "Guest"
- [ ] Verify speaker data persists across app restart
- [ ] Remove a speaker: verify they're gone
- [ ] Test enrollment with different voice qualities

### Performance Testing

- [ ] Verify parallel STT + speaker ID completes quickly
- [ ] No noticeable lag in identification
- [ ] Memory usage acceptable with multiple speakers

### Regression Check

- [ ] Wake word detection still works
- [ ] Transcription still accurate
- [ ] All previous functionality intact

---

## Phase 6: Completion

### Git Commit

```bash
git add .
git commit -m "Milestone 3: Speaker identification with enrollment

- Integrate FluidAudio for speaker embeddings
- Implement SpeakerService with identification and enrollment
- Create Speaker and SpeakerEmbedding models
- Run STT and speaker ID in parallel for speed
- Create enrollment flow UI with multi-sample recording
- Add SpeakersSettingsView for managing speakers
- Persist speaker profiles to JSON storage
- Add comprehensive embedding distance tests"
```

### Ready for Next Milestone

- [ ] All Phase 5 verification items pass
- [ ] Code committed to version control
- [ ] Ready to proceed to [Milestone 4: LLM Integration](./04-llm-integration.md)

---

## Deliverable

App that identifies enrolled speakers by voice. Users can enroll via a guided flow, and the system shows who is speaking (e.g., "Rich said: ...") or "Guest" for unknown speakers.
