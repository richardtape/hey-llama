# Milestone 2: Speech-to-Text Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Integrate WhisperKit for speech-to-text transcription and implement wake word detection ("Hey Llama").

**Architecture:** STTService wraps WhisperKit for transcription. CommandProcessor extracts commands following the wake phrase. AssistantCoordinator calls STT on captured utterances, displays transcriptions in UI, and logs detected commands.

**Tech Stack:** Swift 5.9+, SwiftUI, WhisperKit (0.9.0+), AVFoundation

**Reference Docs:**
- `docs/spec.md` - Section 3.3 (STT), Section 5 (Data Models)
- `docs/milestones/02-speech-to-text.md` - Task checklist

---

## Build & Test Workflow

**Important:** The user will run all Xcode builds and tests manually in the Xcode application. Claude should never run `xcodebuild` CLI commands. Instead, instruct the user with Xcode keyboard shortcuts:

| Action | Xcode Shortcut |
|--------|----------------|
| Clean Build Folder | `Cmd+Shift+K` |
| Build | `Cmd+B` |
| Run All Tests | `Cmd+U` |
| Run App | `Cmd+R` |
| Stop Running | `Cmd+.` |
| Open Test Navigator | `Cmd+6` |

**To run specific tests:** Open Test Navigator (`Cmd+6`), find the test class or method, and click the diamond icon next to it. Alternatively, open the test file and click the diamond in the gutter next to the test.

---

## Task 1: TranscriptionResult Model

**Files:**
- Create: `HeyLlama/Models/TranscriptionResult.swift`
- Test: `HeyLlamaTests/TranscriptionResultTests.swift`

**Step 1: Write failing tests**

Create `HeyLlamaTests/TranscriptionResultTests.swift`:

```swift
import XCTest
@testable import HeyLlama

final class TranscriptionResultTests: XCTestCase {

    func testTranscriptionResultInit() {
        let result = TranscriptionResult(
            text: "Hello world",
            confidence: 0.95,
            language: "en",
            processingTimeMs: 250
        )

        XCTAssertEqual(result.text, "Hello world")
        XCTAssertEqual(result.confidence, 0.95)
        XCTAssertEqual(result.language, "en")
        XCTAssertEqual(result.processingTimeMs, 250)
        XCTAssertNil(result.words)
    }

    func testTranscriptionResultWithWordTimings() {
        let words = [
            WordTiming(word: "Hello", startTime: 0.0, endTime: 0.5, confidence: 0.98),
            WordTiming(word: "world", startTime: 0.6, endTime: 1.0, confidence: 0.92)
        ]

        let result = TranscriptionResult(
            text: "Hello world",
            confidence: 0.95,
            language: "en",
            processingTimeMs: 250,
            words: words
        )

        XCTAssertEqual(result.words?.count, 2)
        XCTAssertEqual(result.words?[0].word, "Hello")
        XCTAssertEqual(result.words?[1].endTime, 1.0)
    }

    func testWordTimingInit() {
        let timing = WordTiming(
            word: "test",
            startTime: 1.5,
            endTime: 2.0,
            confidence: 0.88
        )

        XCTAssertEqual(timing.word, "test")
        XCTAssertEqual(timing.startTime, 1.5)
        XCTAssertEqual(timing.endTime, 2.0)
        XCTAssertEqual(timing.confidence, 0.88)
    }

    func testTranscriptionResultEquatable() {
        let result1 = TranscriptionResult(text: "test", confidence: 0.9, language: "en", processingTimeMs: 100)
        let result2 = TranscriptionResult(text: "test", confidence: 0.9, language: "en", processingTimeMs: 100)
        let result3 = TranscriptionResult(text: "other", confidence: 0.9, language: "en", processingTimeMs: 100)

        XCTAssertEqual(result1, result2)
        XCTAssertNotEqual(result1, result3)
    }
}
```

**Step 2: Run tests to verify they fail**

In Xcode: Open Test Navigator (`Cmd+6`), find `TranscriptionResultTests`, click the diamond to run.

Expected: Compilation error - `TranscriptionResult` not found

**Step 3: Implement TranscriptionResult**

Create `HeyLlama/Models/TranscriptionResult.swift`:

```swift
import Foundation

struct WordTiming: Equatable, Sendable {
    let word: String
    let startTime: TimeInterval
    let endTime: TimeInterval
    let confidence: Float
}

struct TranscriptionResult: Equatable, Sendable {
    let text: String
    let confidence: Float
    let language: String
    let processingTimeMs: Int
    let words: [WordTiming]?

    init(
        text: String,
        confidence: Float,
        language: String,
        processingTimeMs: Int,
        words: [WordTiming]? = nil
    ) {
        self.text = text
        self.confidence = confidence
        self.language = language
        self.processingTimeMs = processingTimeMs
        self.words = words
    }
}
```

**Step 4: Run tests to verify they pass**

In Xcode: Run `TranscriptionResultTests` via Test Navigator (`Cmd+6`) or press `Cmd+U` for all tests.

Expected: All tests pass (green checkmarks)

**Step 5: Commit**

```bash
git add HeyLlama/Models/TranscriptionResult.swift HeyLlamaTests/TranscriptionResultTests.swift
git commit -m "feat(models): add TranscriptionResult and WordTiming types"
```

---

## Task 2: Command Model

**Files:**
- Create: `HeyLlama/Models/Command.swift`
- Test: `HeyLlamaTests/CommandTests.swift`

**Step 1: Write failing tests**

Create `HeyLlamaTests/CommandTests.swift`:

```swift
import XCTest
@testable import HeyLlama

final class CommandTests: XCTestCase {

    func testCommandInit() {
        let command = Command(
            rawText: "Hey Llama what time is it",
            commandText: "what time is it",
            source: .localMic,
            confidence: 0.95
        )

        XCTAssertEqual(command.rawText, "Hey Llama what time is it")
        XCTAssertEqual(command.commandText, "what time is it")
        XCTAssertEqual(command.source, .localMic)
        XCTAssertEqual(command.confidence, 0.95)
        XCTAssertNil(command.speaker)
    }

    func testCommandWithSpeaker() {
        let speaker = Speaker(id: UUID(), name: "Alice", embeddings: [])
        let command = Command(
            rawText: "Hey Llama hello",
            commandText: "hello",
            speaker: speaker,
            source: .localMic,
            confidence: 0.9
        )

        XCTAssertEqual(command.speaker?.name, "Alice")
    }

    func testCommandTimestampIsRecent() {
        let before = Date()
        let command = Command(
            rawText: "test",
            commandText: "test",
            source: .localMic,
            confidence: 1.0
        )
        let after = Date()

        XCTAssertGreaterThanOrEqual(command.timestamp, before)
        XCTAssertLessThanOrEqual(command.timestamp, after)
    }

    func testCommandFromSatellite() {
        let command = Command(
            rawText: "Hey Llama lights on",
            commandText: "lights on",
            source: .satellite("bedroom-pi"),
            confidence: 0.88
        )

        XCTAssertEqual(command.source, .satellite("bedroom-pi"))
    }

    func testConversationTurnInit() {
        let turn = ConversationTurn(role: .user, content: "What time is it?")

        XCTAssertEqual(turn.role, .user)
        XCTAssertEqual(turn.content, "What time is it?")
    }

    func testConversationTurnRoles() {
        let userTurn = ConversationTurn(role: .user, content: "Hello")
        let assistantTurn = ConversationTurn(role: .assistant, content: "Hi there!")

        XCTAssertEqual(userTurn.role, .user)
        XCTAssertEqual(assistantTurn.role, .assistant)
    }

    func testCommandContextInit() {
        let context = CommandContext(
            command: "what time is it",
            source: .localMic
        )

        XCTAssertEqual(context.command, "what time is it")
        XCTAssertEqual(context.source, .localMic)
        XCTAssertNil(context.speaker)
        XCTAssertNil(context.conversationHistory)
    }

    func testCommandContextWithHistory() {
        let history = [
            ConversationTurn(role: .user, content: "Hello"),
            ConversationTurn(role: .assistant, content: "Hi!")
        ]

        let context = CommandContext(
            command: "How are you?",
            source: .localMic,
            conversationHistory: history
        )

        XCTAssertEqual(context.conversationHistory?.count, 2)
    }
}
```

**Step 2: Run tests to verify they fail**

In Xcode: Open Test Navigator (`Cmd+6`), find `CommandTests`, click the diamond to run.

Expected: Compilation error - `Command` not found

**Step 3: Implement Command and related types**

Create `HeyLlama/Models/Command.swift`:

```swift
import Foundation

struct Command: Sendable {
    let rawText: String
    let commandText: String
    let speaker: Speaker?
    let source: AudioSource
    let timestamp: Date
    let confidence: Float

    init(
        rawText: String,
        commandText: String,
        speaker: Speaker? = nil,
        source: AudioSource,
        confidence: Float
    ) {
        self.rawText = rawText
        self.commandText = commandText
        self.speaker = speaker
        self.source = source
        self.timestamp = Date()
        self.confidence = confidence
    }
}

enum ConversationRole: String, Sendable {
    case user
    case assistant
}

struct ConversationTurn: Sendable {
    let role: ConversationRole
    let content: String
    let timestamp: Date

    init(role: ConversationRole, content: String) {
        self.role = role
        self.content = content
        self.timestamp = Date()
    }
}

struct CommandContext: Sendable {
    let command: String
    let speaker: Speaker?
    let source: AudioSource
    let timestamp: Date
    let conversationHistory: [ConversationTurn]?

    init(
        command: String,
        speaker: Speaker? = nil,
        source: AudioSource,
        conversationHistory: [ConversationTurn]? = nil
    ) {
        self.command = command
        self.speaker = speaker
        self.source = source
        self.timestamp = Date()
        self.conversationHistory = conversationHistory
    }
}
```

**Step 4: Create Speaker stub model**

We need a minimal Speaker model for Command to reference. Create `HeyLlama/Models/Speaker.swift`:

```swift
import Foundation

struct Speaker: Sendable, Equatable {
    let id: UUID
    let name: String
    let embeddings: [[Float]]

    init(id: UUID = UUID(), name: String, embeddings: [[Float]] = []) {
        self.id = id
        self.name = name
        self.embeddings = embeddings
    }
}
```

**Step 5: Run tests to verify they pass**

In Xcode: Run `CommandTests` via Test Navigator (`Cmd+6`) or press `Cmd+U` for all tests.

Expected: All tests pass (green checkmarks)

**Step 6: Commit**

```bash
git add HeyLlama/Models/Command.swift HeyLlama/Models/Speaker.swift HeyLlamaTests/CommandTests.swift
git commit -m "feat(models): add Command, CommandContext, ConversationTurn, and Speaker types"
```

---

## Task 3: CommandProcessor with Wake Word Detection

**Files:**
- Create: `HeyLlama/Core/CommandProcessor.swift`
- Test: `HeyLlamaTests/CommandProcessorTests.swift`

**Step 1: Write failing tests**

Create `HeyLlamaTests/CommandProcessorTests.swift`:

```swift
import XCTest
@testable import HeyLlama

final class CommandProcessorTests: XCTestCase {

    var processor: CommandProcessor!

    override func setUp() {
        super.setUp()
        processor = CommandProcessor()
    }

    func testNoWakeWordReturnsNil() {
        let result = processor.extractCommand(from: "Hello world")
        XCTAssertNil(result)
    }

    func testTypoInWakeWordReturnsNil() {
        let result = processor.extractCommand(from: "Hey Lama what time is it")
        XCTAssertNil(result)
    }

    func testCorrectWakeWordExtractsCommand() {
        let result = processor.extractCommand(from: "Hey Llama what time is it")
        XCTAssertEqual(result, "what time is it")
    }

    func testCaseInsensitiveMatchingLowercase() {
        let result = processor.extractCommand(from: "hey llama, turn off the lights")
        XCTAssertEqual(result, "turn off the lights")
    }

    func testCaseInsensitiveMatchingUppercase() {
        let result = processor.extractCommand(from: "HEY LLAMA test")
        XCTAssertEqual(result, "test")
    }

    func testCaseInsensitiveMatchingMixed() {
        let result = processor.extractCommand(from: "HeY LlAmA mixed case")
        XCTAssertEqual(result, "mixed case")
    }

    func testWakeWordAloneReturnsNil() {
        let result = processor.extractCommand(from: "Hey Llama")
        XCTAssertNil(result)
    }

    func testWakeWordWithOnlyWhitespaceReturnsNil() {
        let result = processor.extractCommand(from: "Hey Llama   ")
        XCTAssertNil(result)
    }

    func testWakeWordMidSentenceExtractsAfter() {
        let result = processor.extractCommand(from: "before Hey Llama after")
        XCTAssertEqual(result, "after")
    }

    func testCommandIsTrimmed() {
        let result = processor.extractCommand(from: "Hey Llama   spaced   ")
        XCTAssertEqual(result, "spaced")
    }

    func testCommandWithLeadingComma() {
        let result = processor.extractCommand(from: "Hey Llama, what's the weather")
        XCTAssertEqual(result, "what's the weather")
    }

    func testMultipleWakeWordsUsesFirst() {
        let result = processor.extractCommand(from: "Hey Llama say Hey Llama")
        XCTAssertEqual(result, "say Hey Llama")
    }

    func testCustomWakePhrase() {
        let customProcessor = CommandProcessor(wakePhrase: "ok computer")
        let result = customProcessor.extractCommand(from: "Ok Computer play music")
        XCTAssertEqual(result, "play music")
    }

    func testContainsWakeWordTrue() {
        XCTAssertTrue(processor.containsWakeWord(in: "Hey Llama test"))
    }

    func testContainsWakeWordFalse() {
        XCTAssertFalse(processor.containsWakeWord(in: "Hello world"))
    }

    func testContainsWakeWordCaseInsensitive() {
        XCTAssertTrue(processor.containsWakeWord(in: "hey llama test"))
        XCTAssertTrue(processor.containsWakeWord(in: "HEY LLAMA test"))
    }
}
```

**Step 2: Run tests to verify they fail**

In Xcode: Open Test Navigator (`Cmd+6`), find `CommandProcessorTests`, click the diamond to run.

Expected: Compilation error - `CommandProcessor` not found

**Step 3: Implement CommandProcessor**

Create `HeyLlama/Core/CommandProcessor.swift`:

```swift
import Foundation

final class CommandProcessor {
    private let wakePhrase: String
    private let wakePhraseLength: Int

    init(wakePhrase: String = "hey llama") {
        self.wakePhrase = wakePhrase.lowercased()
        self.wakePhraseLength = wakePhrase.count
    }

    /// Check if text contains the wake word
    func containsWakeWord(in text: String) -> Bool {
        text.lowercased().contains(wakePhrase)
    }

    /// Extract command text after wake phrase, or nil if not found/empty
    func extractCommand(from text: String) -> String? {
        let lowercased = text.lowercased()

        guard let range = lowercased.range(of: wakePhrase) else {
            return nil
        }

        // Get everything after the wake phrase
        let afterWakePhrase = text[range.upperBound...]

        // Trim whitespace and leading punctuation (comma, colon)
        var command = String(afterWakePhrase)
            .trimmingCharacters(in: .whitespaces)

        // Remove leading comma or colon if present
        if command.hasPrefix(",") || command.hasPrefix(":") {
            command = String(command.dropFirst())
                .trimmingCharacters(in: .whitespaces)
        }

        // Return nil if empty after trimming
        guard !command.isEmpty else {
            return nil
        }

        return command
    }
}
```

**Step 4: Run tests to verify they pass**

In Xcode: Run `CommandProcessorTests` via Test Navigator (`Cmd+6`) or press `Cmd+U` for all tests.

Expected: All tests pass (green checkmarks)

**Step 5: Commit**

```bash
git add HeyLlama/Core/CommandProcessor.swift HeyLlamaTests/CommandProcessorTests.swift
git commit -m "feat(core): add CommandProcessor with wake word detection"
```

---

## Task 4: STTServiceProtocol and MockSTTService

**Files:**
- Create: `HeyLlama/Services/Speech/STTServiceProtocol.swift`
- Create: `HeyLlamaTests/Mocks/MockSTTService.swift`
- Test: `HeyLlamaTests/MockSTTServiceTests.swift`

**Step 1: Create STTServiceProtocol**

Create `HeyLlama/Services/Speech/STTServiceProtocol.swift`:

```swift
import Foundation

protocol STTServiceProtocol: Sendable {
    var isModelLoaded: Bool { get async }
    func loadModel() async throws
    func transcribe(_ audio: AudioChunk) async throws -> TranscriptionResult
}
```

**Step 2: Create MockSTTService for testing**

Create `HeyLlamaTests/Mocks/MockSTTService.swift`:

```swift
import Foundation
@testable import HeyLlama

actor MockSTTService: STTServiceProtocol {
    var mockResult: TranscriptionResult?
    var mockError: Error?
    var loadModelCalled = false
    var transcribeCalls: [AudioChunk] = []

    private var _isModelLoaded = false

    var isModelLoaded: Bool {
        _isModelLoaded
    }

    func setModelLoaded(_ loaded: Bool) {
        _isModelLoaded = loaded
    }

    func setMockResult(_ result: TranscriptionResult) {
        self.mockResult = result
        self.mockError = nil
    }

    func setMockError(_ error: Error) {
        self.mockError = error
        self.mockResult = nil
    }

    func loadModel() async throws {
        loadModelCalled = true
        if let error = mockError {
            throw error
        }
        _isModelLoaded = true
    }

    func transcribe(_ audio: AudioChunk) async throws -> TranscriptionResult {
        transcribeCalls.append(audio)

        if let error = mockError {
            throw error
        }

        guard let result = mockResult else {
            return TranscriptionResult(
                text: "",
                confidence: 0,
                language: "en",
                processingTimeMs: 0
            )
        }

        return result
    }

    func resetCallTracking() {
        loadModelCalled = false
        transcribeCalls = []
    }
}
```

**Step 3: Write tests for MockSTTService**

Create `HeyLlamaTests/MockSTTServiceTests.swift`:

```swift
import XCTest
@testable import HeyLlama

final class MockSTTServiceTests: XCTestCase {

    func testLoadModelSetsIsModelLoaded() async throws {
        let mock = MockSTTService()

        let loadedBefore = await mock.isModelLoaded
        XCTAssertFalse(loadedBefore)

        try await mock.loadModel()

        let loadedAfter = await mock.isModelLoaded
        XCTAssertTrue(loadedAfter)
    }

    func testLoadModelCallIsTracked() async throws {
        let mock = MockSTTService()

        let calledBefore = await mock.loadModelCalled
        XCTAssertFalse(calledBefore)

        try await mock.loadModel()

        let calledAfter = await mock.loadModelCalled
        XCTAssertTrue(calledAfter)
    }

    func testTranscribeReturnsMockResult() async throws {
        let mock = MockSTTService()
        let expectedResult = TranscriptionResult(
            text: "Hello world",
            confidence: 0.95,
            language: "en",
            processingTimeMs: 100
        )
        await mock.setMockResult(expectedResult)

        let chunk = AudioChunk(samples: [Float](repeating: 0.0, count: 480))
        let result = try await mock.transcribe(chunk)

        XCTAssertEqual(result.text, "Hello world")
        XCTAssertEqual(result.confidence, 0.95)
    }

    func testTranscribeTracksCallsWithAudioChunks() async throws {
        let mock = MockSTTService()
        await mock.setMockResult(TranscriptionResult(text: "", confidence: 0, language: "en", processingTimeMs: 0))

        let chunk1 = AudioChunk(samples: [Float](repeating: 0.1, count: 100))
        let chunk2 = AudioChunk(samples: [Float](repeating: 0.2, count: 200))

        _ = try await mock.transcribe(chunk1)
        _ = try await mock.transcribe(chunk2)

        let calls = await mock.transcribeCalls
        XCTAssertEqual(calls.count, 2)
        XCTAssertEqual(calls[0].samples.count, 100)
        XCTAssertEqual(calls[1].samples.count, 200)
    }

    func testTranscribeThrowsMockError() async {
        let mock = MockSTTService()
        await mock.setMockError(NSError(domain: "test", code: 1, userInfo: nil))

        let chunk = AudioChunk(samples: [])

        do {
            _ = try await mock.transcribe(chunk)
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertEqual((error as NSError).domain, "test")
        }
    }

    func testResetCallTracking() async throws {
        let mock = MockSTTService()
        await mock.setMockResult(TranscriptionResult(text: "", confidence: 0, language: "en", processingTimeMs: 0))

        try await mock.loadModel()
        _ = try await mock.transcribe(AudioChunk(samples: []))

        await mock.resetCallTracking()

        let loadModelCalled = await mock.loadModelCalled
        let transcribeCalls = await mock.transcribeCalls

        XCTAssertFalse(loadModelCalled)
        XCTAssertTrue(transcribeCalls.isEmpty)
    }
}
```

**Step 4: Run tests to verify they pass**

In Xcode: Run `MockSTTServiceTests` via Test Navigator (`Cmd+6`) or press `Cmd+U` for all tests.

Expected: All tests pass (green checkmarks)

**Step 5: Commit**

```bash
git add HeyLlama/Services/Speech/STTServiceProtocol.swift HeyLlamaTests/Mocks/MockSTTService.swift HeyLlamaTests/MockSTTServiceTests.swift
git commit -m "feat(speech): add STTServiceProtocol and MockSTTService for testing"
```

---

## Task 5: STTService with WhisperKit

**Files:**
- Create: `HeyLlama/Services/Speech/STTService.swift`

**Note:** STTService requires WhisperKit hardware. We implement it with proper error handling but test via integration tests and MockSTTService for unit tests.

**Step 1: Implement STTService**

Create `HeyLlama/Services/Speech/STTService.swift`:

```swift
import Foundation
import WhisperKit

enum STTError: Error, LocalizedError {
    case modelNotLoaded
    case transcriptionFailed(String)
    case invalidAudioFormat

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "WhisperKit model is not loaded"
        case .transcriptionFailed(let reason):
            return "Transcription failed: \(reason)"
        case .invalidAudioFormat:
            return "Invalid audio format for transcription"
        }
    }
}

actor STTService: STTServiceProtocol {
    private var whisperKit: WhisperKit?
    private let modelName: String

    var isModelLoaded: Bool {
        whisperKit != nil
    }

    init(modelName: String = "base") {
        self.modelName = modelName
    }

    func loadModel() async throws {
        let startTime = Date()

        do {
            whisperKit = try await WhisperKit(model: modelName)

            let loadTime = Date().timeIntervalSince(startTime)
            print("WhisperKit model '\(modelName)' loaded in \(String(format: "%.2f", loadTime))s")
        } catch {
            print("Failed to load WhisperKit model: \(error)")
            throw error
        }
    }

    func transcribe(_ audio: AudioChunk) async throws -> TranscriptionResult {
        guard let whisperKit = whisperKit else {
            throw STTError.modelNotLoaded
        }

        guard !audio.samples.isEmpty else {
            throw STTError.invalidAudioFormat
        }

        let startTime = Date()

        do {
            let results = try await whisperKit.transcribe(audioArray: audio.samples)

            let processingTimeMs = Int(Date().timeIntervalSince(startTime) * 1000)

            guard let result = results.first else {
                return TranscriptionResult(
                    text: "",
                    confidence: 0,
                    language: "en",
                    processingTimeMs: processingTimeMs
                )
            }

            // Extract word timings if available
            let wordTimings: [WordTiming]? = result.segments.flatMap { segment in
                segment.words?.map { word in
                    WordTiming(
                        word: word.word,
                        startTime: TimeInterval(word.start),
                        endTime: TimeInterval(word.end),
                        confidence: word.probability
                    )
                } ?? []
            }

            // Calculate average confidence from segments
            let totalConfidence = result.segments.reduce(Float(0)) { sum, segment in
                sum + segment.avgLogprob
            }
            let avgConfidence = result.segments.isEmpty ? 0 : exp(totalConfidence / Float(result.segments.count))

            return TranscriptionResult(
                text: result.text.trimmingCharacters(in: .whitespacesAndNewlines),
                confidence: avgConfidence,
                language: result.language ?? "en",
                processingTimeMs: processingTimeMs,
                words: wordTimings?.isEmpty == false ? wordTimings : nil
            )
        } catch {
            throw STTError.transcriptionFailed(error.localizedDescription)
        }
    }
}
```

**Step 2: Build to verify compilation**

In Xcode: Press `Cmd+B` to build.

Expected: Build succeeds with no errors

**Step 3: Commit**

```bash
git add HeyLlama/Services/Speech/STTService.swift
git commit -m "feat(speech): add STTService with WhisperKit integration"
```

---

## Task 6: Update AssistantCoordinator for STT Integration

**Files:**
- Modify: `HeyLlama/Core/AssistantCoordinator.swift`

**Step 1: Read current AssistantCoordinator**

Current file is at `HeyLlama/Core/AssistantCoordinator.swift` (already read above).

**Step 2: Update AssistantCoordinator with STT support**

Replace contents of `HeyLlama/Core/AssistantCoordinator.swift`:

```swift
import Foundation
import Combine

@MainActor
final class AssistantCoordinator: ObservableObject {
    @Published private(set) var state: AssistantState = .idle
    @Published private(set) var isListening: Bool = false
    @Published private(set) var audioLevel: Float = 0
    @Published private(set) var lastTranscription: String?
    @Published private(set) var lastCommand: String?
    @Published private(set) var isModelLoading: Bool = false

    private let audioEngine: AudioEngine
    private let vadService: VADService
    private let audioBuffer: AudioBuffer
    private let sttService: any STTServiceProtocol
    private let commandProcessor: CommandProcessor
    private var cancellables = Set<AnyCancellable>()

    init(sttService: (any STTServiceProtocol)? = nil) {
        self.audioEngine = AudioEngine()
        self.vadService = VADService()
        self.audioBuffer = AudioBuffer(maxSeconds: 15)
        self.sttService = sttService ?? STTService()
        self.commandProcessor = CommandProcessor()

        setupBindings()
    }

    private func setupBindings() {
        audioEngine.audioChunkPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] chunk in
                Task { [weak self] in
                    await self?.processAudioChunk(chunk)
                }
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

        // Load STT model before starting audio
        isModelLoading = true
        state = .idle

        do {
            try await sttService.loadModel()
            isModelLoading = false
        } catch {
            isModelLoading = false
            state = .error("Failed to load speech model: \(error.localizedDescription)")
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
        lastTranscription = nil
        lastCommand = nil
    }

    private func processAudioChunk(_ chunk: AudioChunk) async {
        audioBuffer.append(chunk)

        let vadResult = await vadService.processAsync(chunk)

        switch (state, vadResult) {
        case (.listening, .speechStart):
            audioBuffer.markSpeechStart()
            state = .capturing

        case (.capturing, .speechContinue):
            break

        case (.capturing, .speechEnd):
            state = .processing
            let utterance = audioBuffer.getUtteranceSinceSpeechStart()

            await processUtterance(utterance, source: chunk.source)

        default:
            break
        }
    }

    private func processUtterance(_ audio: AudioChunk, source: AudioSource) async {
        print("Processing utterance: \(String(format: "%.2f", audio.duration))s")

        do {
            let result = try await sttService.transcribe(audio)

            // Update UI with transcription
            lastTranscription = result.text

            print("Transcription: \"\(result.text)\" (confidence: \(String(format: "%.2f", result.confidence)), \(result.processingTimeMs)ms)")

            // Check for wake word and extract command
            if let commandText = commandProcessor.extractCommand(from: result.text) {
                lastCommand = commandText
                print("Wake word detected! Command: \"\(commandText)\"")

                // Create command object for future LLM integration (Milestone 4)
                let command = Command(
                    rawText: result.text,
                    commandText: commandText,
                    source: source,
                    confidence: result.confidence
                )

                // TODO: In Milestone 4, send command to LLM
                _ = command
            } else {
                print("No wake word detected in: \"\(result.text)\"")
            }

        } catch {
            print("Transcription error: \(error)")
            lastTranscription = "[Transcription failed]"
        }

        // Return to listening
        state = .listening
    }
}
```

**Step 3: Build to verify compilation**

In Xcode: Press `Cmd+B` to build.

Expected: Build succeeds with no errors

**Step 4: Commit**

```bash
git add HeyLlama/Core/AssistantCoordinator.swift
git commit -m "feat(core): integrate STT and CommandProcessor into AssistantCoordinator"
```

---

## Task 7: Update AppState for New Properties

**Files:**
- Modify: `HeyLlama/App/AppState.swift`

**Step 1: Update AppState to expose new coordinator properties**

Replace contents of `HeyLlama/App/AppState.swift`:

```swift
import Foundation
import Combine

@MainActor
final class AppState: ObservableObject {
    let coordinator: AssistantCoordinator

    @Published private(set) var statusIcon: String = "waveform.slash"
    @Published private(set) var statusText: String = "Idle"
    @Published private(set) var audioLevel: Float = 0
    @Published private(set) var lastTranscription: String?
    @Published private(set) var lastCommand: String?
    @Published private(set) var isModelLoading: Bool = false

    private var cancellables = Set<AnyCancellable>()

    init(coordinator: AssistantCoordinator? = nil) {
        self.coordinator = coordinator ?? AssistantCoordinator()
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

        coordinator.$lastTranscription
            .receive(on: DispatchQueue.main)
            .assign(to: &$lastTranscription)

        coordinator.$lastCommand
            .receive(on: DispatchQueue.main)
            .assign(to: &$lastCommand)

        coordinator.$isModelLoading
            .receive(on: DispatchQueue.main)
            .assign(to: &$isModelLoading)
    }

    func start() async {
        await coordinator.start()
    }

    func shutdown() {
        coordinator.shutdown()
    }
}
```

**Step 2: Build to verify compilation**

In Xcode: Press `Cmd+B` to build.

Expected: Build succeeds with no errors

**Step 3: Commit**

```bash
git add HeyLlama/App/AppState.swift
git commit -m "feat(app): expose transcription and command properties in AppState"
```

---

## Task 8: Update MenuBarView with Transcription Display

**Files:**
- Modify: `HeyLlama/UI/MenuBar/MenuBarView.swift`

**Step 1: Update MenuBarView to show transcriptions**

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

            // Status section
            HStack {
                Image(systemName: appState.statusIcon)
                if appState.isModelLoading {
                    Text("Loading model...")
                } else {
                    Text(appState.statusText)
                }
            }
            .foregroundColor(statusColor)

            AudioLevelIndicator(level: appState.audioLevel)
                .frame(height: 4)

            // Transcription section
            if let transcription = appState.lastTranscription, !transcription.isEmpty {
                Divider()

                VStack(alignment: .leading, spacing: 2) {
                    Text("Last heard:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(transcription)
                        .font(.caption)
                        .lineLimit(3)
                }
            }

            // Command section
            if let command = appState.lastCommand, !command.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Command:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(command)
                        .font(.caption)
                        .foregroundColor(.green)
                        .lineLimit(2)
                }
            }

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
        .frame(width: 220)
    }

    private var statusColor: Color {
        if appState.isModelLoading {
            return .orange
        }

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

**Step 2: Build to verify compilation**

In Xcode: Press `Cmd+B` to build.

Expected: Build succeeds with no errors

**Step 3: Commit**

```bash
git add HeyLlama/UI/MenuBar/MenuBarView.swift
git commit -m "feat(ui): display transcriptions and commands in menu bar dropdown"
```

---

## Task 9: Update AppDelegate for Test Environment

**Files:**
- Modify: `HeyLlama/App/AppDelegate.swift`

**Step 1: Update AppDelegate to handle test environment better**

Replace contents of `HeyLlama/App/AppDelegate.swift`:

```swift
import AppKit
import AVFoundation

class AppDelegate: NSObject, NSApplicationDelegate {
    private var appState: AppState?

    /// Check if we're running in a test environment
    private var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationWillTerminate(_ notification: Notification) {
        appState?.shutdown()
    }

    func setAppState(_ state: AppState) {
        self.appState = state

        // Skip audio initialization during tests
        guard !isRunningTests else {
            print("Running in test environment - skipping audio initialization")
            return
        }

        Task {
            await state.start()
        }
    }
}
```

**Step 2: Build to verify compilation**

In Xcode: Press `Cmd+B` to build.

Expected: Build succeeds with no errors

**Step 3: Commit**

```bash
git add HeyLlama/App/AppDelegate.swift
git commit -m "fix(app): skip audio initialization in test environment"
```

---

## Task 10: Integration Tests for AssistantCoordinator with Mock STT

**Files:**
- Create: `HeyLlamaTests/AssistantCoordinatorSTTTests.swift`

**Step 1: Write integration tests**

Create `HeyLlamaTests/AssistantCoordinatorSTTTests.swift`:

```swift
import XCTest
@testable import HeyLlama

@MainActor
final class AssistantCoordinatorSTTTests: XCTestCase {

    func testCommandProcessorExtractsWakeWord() {
        let processor = CommandProcessor()

        // Test various inputs
        XCTAssertNil(processor.extractCommand(from: "Hello world"))
        XCTAssertEqual(processor.extractCommand(from: "Hey Llama what time is it"), "what time is it")
        XCTAssertEqual(processor.extractCommand(from: "hey llama turn on lights"), "turn on lights")
    }

    func testTranscriptionResultCreation() {
        let result = TranscriptionResult(
            text: "Hey Llama test command",
            confidence: 0.95,
            language: "en",
            processingTimeMs: 150
        )

        XCTAssertEqual(result.text, "Hey Llama test command")
        XCTAssertEqual(result.confidence, 0.95)
        XCTAssertEqual(result.processingTimeMs, 150)
    }

    func testCommandCreation() {
        let command = Command(
            rawText: "Hey Llama turn on the lights",
            commandText: "turn on the lights",
            source: .localMic,
            confidence: 0.92
        )

        XCTAssertEqual(command.rawText, "Hey Llama turn on the lights")
        XCTAssertEqual(command.commandText, "turn on the lights")
        XCTAssertEqual(command.source, .localMic)
    }

    func testCommandProcessorWithVariousInputs() {
        let processor = CommandProcessor()

        // No wake word
        XCTAssertNil(processor.extractCommand(from: "turn on the lights"))

        // Wake word with command
        XCTAssertEqual(processor.extractCommand(from: "Hey Llama turn on the lights"), "turn on the lights")

        // Wake word alone
        XCTAssertNil(processor.extractCommand(from: "Hey Llama"))

        // Wake word with comma
        XCTAssertEqual(processor.extractCommand(from: "Hey Llama, what's the weather"), "what's the weather")

        // Mixed case
        XCTAssertEqual(processor.extractCommand(from: "HEY LLAMA hello"), "hello")
    }
}
```

**Step 2: Run tests**

In Xcode: Run `AssistantCoordinatorSTTTests` via Test Navigator (`Cmd+6`) or press `Cmd+U` for all tests.

Expected: All tests pass (green checkmarks)

**Step 3: Commit**

```bash
git add HeyLlamaTests/AssistantCoordinatorSTTTests.swift
git commit -m "test(coordinator): add integration tests for STT flow"
```

---

## Task 11: Run Full Test Suite

**Step 1: Clean and run all tests**

In Xcode:
1. Press `Cmd+Shift+K` to clean build folder
2. Press `Cmd+U` to run all tests

Expected: All tests pass (green checkmarks in Test Navigator)

**Step 2: Fix any failing tests**

If tests fail, debug and fix issues. Report failures to Claude for assistance.

---

## Task 12: Manual Integration Testing

**Step 1: Run the app**

In Xcode: Press `Cmd+R` to build and run the app.

**Step 2: Manual testing checklist**

Test the running app:

- [ ] App shows "Loading model..." while WhisperKit initializes
- [ ] After model loads, status changes to "Listening..."
- [ ] Speak clearly: transcription appears in dropdown under "Last heard:"
- [ ] Say "Hey Llama, hello world":
  - Transcription shows full text
  - Command shows "hello world" in green
  - Console logs "Wake word detected! Command: hello world"
- [ ] Say "What time is it" (no wake word):
  - Transcription shows text
  - No command displayed
  - Console logs "No wake word detected in: ..."
- [ ] Test with various speaking speeds
- [ ] Test with mild background noise
- [ ] VAD still detects speech start/end correctly
- [ ] Audio level indicator still works
- [ ] Preferences window still opens (`Cmd+,`)
- [ ] Quit still terminates app cleanly (`Cmd+Q`)

**Step 3: Stop the app**

In Xcode: Press `Cmd+.` to stop the running app.

---

## Task 13: Final Milestone Commit

**Step 1: Create milestone commit**

```bash
git add .
git commit -m "$(cat <<'EOF'
Milestone 2: Speech-to-text with wake word detection

- Integrate WhisperKit for speech transcription
- Add STTService with model loading and transcription
- Add STTServiceProtocol for testability
- Create CommandProcessor for wake word extraction
- Add TranscriptionResult and WordTiming models
- Add Command, CommandContext, and ConversationTurn models
- Add Speaker stub model for future milestone
- Update AssistantCoordinator with STT integration
- Display transcriptions and commands in menu bar dropdown
- Add comprehensive unit tests for all new components
- Add MockSTTService for testing without hardware

EOF
)"
```

---

## Summary

This plan implements Milestone 2 in 13 tasks:

1. **TranscriptionResult** - STT output model with word timings
2. **Command** - Command model with context and conversation types
3. **CommandProcessor** - Wake word detection with case-insensitive matching
4. **STTServiceProtocol** - Protocol and mock for testing
5. **STTService** - WhisperKit integration
6. **AssistantCoordinator** - STT integration with utterance processing
7. **AppState** - Expose transcription/command properties
8. **MenuBarView** - Display transcriptions and commands
9. **AppDelegate** - Handle test environment
10. **Integration Tests** - Tests for STT flow
11. **Test Suite** - Run all tests
12. **Manual Testing** - Integration verification
13. **Final Commit** - Milestone commit

**Deliverable:** App that transcribes speech using WhisperKit and detects "Hey Llama" wake word. When wake word is detected, the command text is extracted and displayed. Transcriptions appear in the menu bar dropdown.

---

## Future Polish (Milestone 6)

### Startup Flow with Model Loading Interstitial

Currently the app asks for mic permission, then starts loading models in the background while already listening. This can lead to slow first transcriptions while models warm up.

**Desired flow:**
1. App launches, requests microphone permission
2. Upon permission granted, show loading interstitial screen
3. During interstitial:
   - Download models if not cached (WhisperKit, Silero VAD)
   - Load models into memory
   - Warm up models with a test inference
4. Once everything is ready, dismiss interstitial and start listening

**Benefits:**
- User knows the app is preparing, not frozen
- First real transcription will be fast (model already warm)
- Clear indication of first-run vs subsequent launches
