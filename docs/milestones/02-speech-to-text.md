# Milestone 2: Speech-to-Text

## Overview

For general project context, see:
- [`CLAUDE.md`](../../CLAUDE.md) - Quick reference for architecture and patterns
- [`docs/spec.md`](../spec.md) - Complete technical specification (Sections 3.3, 5.3)

## Goal

Integrate WhisperKit for speech-to-text transcription and implement wake word detection. When the user says "Hey Llama" followed by a command, extract the command text.

## Prerequisites

- Milestone 1 complete (audio capture and VAD working)

---

## Phase 1: Design

Key design decisions for this milestone:

- [ ] Confirm wake phrase: "hey llama" (case-insensitive)
- [ ] Confirm WhisperKit model size: base or small (balance speed vs accuracy)
- [ ] Confirm wake word matching: substring search (not start-of-string)
- [ ] Confirm command extraction: everything after wake phrase, trimmed

---

## Phase 2: Test Setup

### Create Test Infrastructure

- [ ] Create `CommandProcessorTests.swift` in test target
- [ ] Create `MockSTTService.swift` in `HeyLlamaTests/Mocks/`

### Write CommandProcessor Tests (RED - write before implementation)

```swift
// Tests to write before implementation:
func testNoWakeWordReturnsNil()
func testTypoInWakeWordReturnsNil()
func testCorrectWakeWordExtractsCommand()
func testCaseInsensitiveMatching()
func testWakeWordAloneReturnsNil()
func testWakeWordMidSentenceExtractsAfter()
func testCommandIsTrimmed()
```

- [ ] Test: "Hello world" returns `nil` (no wake word)
- [ ] Test: "Hey Lama what time is it" returns `nil` (typo)
- [ ] Test: "Hey Llama what time is it" returns "what time is it"
- [ ] Test: "hey llama, turn off the lights" returns "turn off the lights"
- [ ] Test: "HEY LLAMA test" returns "test" (case insensitive)
- [ ] Test: "Hey Llama" alone returns `nil` (nothing after)
- [ ] Test: "before Hey Llama after" returns "after"
- [ ] Test: "Hey Llama   spaced   " returns "spaced" (trimmed)

### Create MockSTTService

- [ ] Implement `STTServiceProtocol`
- [ ] Allow setting `mockResult: TranscriptionResult`
- [ ] Track `transcribeCalls: [AudioChunk]` for verification
- [ ] Implement `isModelLoaded` as settable property

---

## Phase 3: Implementation

### Define Models

#### TranscriptionResult Model

- [ ] Create `TranscriptionResult.swift` in `Models/`
- [ ] Define `text: String` property
- [ ] Define `confidence: Float` property
- [ ] Define `words: [WordTiming]?` property (optional)
- [ ] Define `language: String` property
- [ ] Define `processingTimeMs: Int` property

#### WordTiming Struct

- [ ] Create `WordTiming` struct in `TranscriptionResult.swift`
- [ ] Define `word: String`, `startTime: TimeInterval`, `endTime: TimeInterval`, `confidence: Float`

#### Command Model

- [ ] Create `Command.swift` in `Models/`
- [ ] Define `rawText: String` (full transcription)
- [ ] Define `commandText: String` (text after wake word)
- [ ] Define `speaker: Speaker?` (populated in M3)
- [ ] Define `source: AudioSource`
- [ ] Define `timestamp: Date`
- [ ] Define `confidence: Float`

#### CommandContext Model

- [ ] Create `CommandContext` struct in `Command.swift`
- [ ] Define `command: String`
- [ ] Define `speaker: Speaker?`
- [ ] Define `source: AudioSource`
- [ ] Define `timestamp: Date`
- [ ] Define `conversationHistory: [ConversationTurn]?`

#### ConversationTurn Model

- [ ] Create `ConversationTurn` struct
- [ ] Define `Role` enum: `.user`, `.assistant`
- [ ] Define `role: Role`, `content: String`, `timestamp: Date`

### Define STTServiceProtocol

- [ ] Create `STTServiceProtocol.swift` in `Services/Speech/`
- [ ] Define `func loadModel() async`
- [ ] Define `func transcribe(_ audio: AudioChunk) async -> TranscriptionResult`
- [ ] Define `var isModelLoaded: Bool { get }`

### Implement CommandProcessor

- [ ] Create `CommandProcessor.swift` in `Core/`
- [ ] Define `wakePhrase: String` property (default "hey llama")
- [ ] Store wake phrase lowercased for comparison

#### CommandProcessor Methods

- [ ] Implement `extractCommand(from text: String) -> String?`
  - Convert input to lowercase
  - Search for wake phrase
  - Extract everything after wake phrase
  - Trim whitespace
  - Return `nil` if not found or empty

### Implement STTService

- [ ] Create `STTService.swift` in `Services/Speech/`
- [ ] Import WhisperKit
- [ ] Conform to `STTServiceProtocol`
- [ ] Create private `whisperPipeline: WhisperKit?`
- [ ] Implement `isModelLoaded` based on pipeline presence

#### STTService Methods

- [ ] Implement `loadModel() async`
  - Initialize WhisperKit with chosen model
  - Handle model download if needed
  - Log loading time
  - Handle errors gracefully

- [ ] Implement `transcribe(_ audio: AudioChunk) async -> TranscriptionResult`
  - Convert AudioChunk to WhisperKit format
  - Call transcription
  - Measure processing time
  - Map result to TranscriptionResult
  - Extract word timings if available

---

## Phase 4: Integration

### Add to Coordinator

- [ ] Add `sttService: STTServiceProtocol` to `AssistantCoordinator`
- [ ] Accept optional protocol in init (for testing)
- [ ] Default to `STTService()` if not provided
- [ ] Add `commandProcessor: CommandProcessor`
- [ ] Add `@Published lastTranscription: String?`

### Update Coordinator Start

- [ ] Call `sttService.loadModel()` in `start()` method
- [ ] Show loading state while model loads
- [ ] Disable listening until model ready

### Implement Utterance Processing

- [ ] Create `processUtterance(_ audio: AudioChunk, source: AudioSource) async`
- [ ] Call `sttService.transcribe(audio)`
- [ ] Update `lastTranscription`
- [ ] Call `commandProcessor.extractCommand()`
- [ ] If no wake word: return to `.listening`
- [ ] If wake word found: log command (LLM in M4)

### Update VAD Handler

- [ ] On `.speechEnd`, call `processUtterance()` with extracted audio

### Update Menu Bar UI

- [ ] Display last transcription in dropdown
- [ ] Show "Processing..." during transcription
- [ ] Show model loading progress on startup
- [ ] Indicate when STT is ready

---

## Phase 5: Verification

### Test Suite

- [ ] Run all unit tests: `xcodebuild test -scheme HeyLlama`
- [ ] All CommandProcessor tests pass (GREEN)
- [ ] Mock STTService tests pass
- [ ] Previous milestone tests still pass

### Manual Testing

- [ ] App shows loading state while WhisperKit initializes
- [ ] Speak clearly: transcription appears in dropdown
- [ ] Say "Hey Llama, hello world": console logs "hello world"
- [ ] Say "What time is it" (no wake word): no command extracted
- [ ] Test with various speaking speeds
- [ ] Test transcription accuracy in quiet environment
- [ ] Test with mild background noise

### Regression Check

- [ ] VAD still detects speech start/end correctly
- [ ] Audio level indicator still works
- [ ] All Milestone 0/1 functionality intact

---

## Phase 6: Completion

### Git Commit

```bash
git add .
git commit -m "Milestone 2: Speech-to-text with wake word detection

- Integrate WhisperKit for transcription
- Implement STTService with model loading
- Create CommandProcessor for wake word extraction
- Add TranscriptionResult and Command models
- Display transcriptions in menu bar dropdown
- Add comprehensive CommandProcessor unit tests"
```

### Ready for Next Milestone

- [ ] All Phase 5 verification items pass
- [ ] Code committed to version control
- [ ] Ready to proceed to [Milestone 3: Speaker Identification](./03-speaker-identification.md)

---

## Deliverable

App that transcribes speech using WhisperKit and detects "Hey Llama" wake word. When wake word is detected, the command text is extracted and logged. Transcriptions appear in the menu bar dropdown.
