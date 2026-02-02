# Milestone 4: LLM Integration Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Integrate LLM providers (Apple Intelligence and OpenAI-compatible) to turn wake-word commands into text responses, with support for multi-turn conversations.

**Architecture:** LLMService provides a protocol-based abstraction over multiple LLM providers. A ConversationManager maintains conversation history with time-based windowing to determine context relevance. AssistantCoordinator calls LLM after extracting commands and displays responses in the menu bar UI.

**Tech Stack:** Swift 5.9+, SwiftUI, URLSession (OpenAI API), Foundation.LanguageModel (Apple Intelligence)

**Reference Docs:**
- `docs/spec.md` - Section 7 (Configuration)
- `docs/milestones/04-llm-integration.md` - Task checklist
- `CLAUDE.md` - Architecture overview

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

## Design Decisions

### Multi-Turn Conversation Strategy

The user raised an important consideration: how to determine when conversation history should be included with an LLM request.

**Problem:** 
- "What's the capital of France?" → "Paris"
- "What language do they speak there?" → needs context
- "Add pepper to the groceries list" → unrelated, fresh start

**Solution: Time-Based Conversation Windows**

We'll use a simple, pragmatic approach:

1. **Conversation Session**: Maintain a list of recent `ConversationTurn` entries
2. **Time Window**: Include turns from the last N minutes (configurable, default 5 minutes)
3. **Maximum Turns**: Cap at last M turns (configurable, default 10) to manage token limits
4. **Automatic Expiry**: Turns older than the time window are pruned on each request
5. **Manual Reset**: User can say "Hey Llama, new conversation" (future enhancement)

**Why this approach:**
- Simple to implement and understand
- Works well for typical voice assistant usage patterns
- No complex topic detection needed
- LLMs are good at ignoring irrelevant context
- Token costs are manageable with reasonable limits

**Future enhancements (not in this milestone):**
- Topic detection using embeddings
- Per-speaker conversation histories
- Explicit conversation threading

### LLM Provider Strategy

1. **Primary:** Apple Intelligence (on-device, private, free)
2. **Fallback:** OpenAI-compatible API (Ollama, LM Studio, etc.)

The config specifies which provider is active. If Apple Intelligence is unavailable (older macOS/device), fall back gracefully.

---

## Task 1: LLMConfig and LLMProvider Models

**Files:**
- Create: `HeyLlama/Storage/LLMConfig.swift`
- Test: `HeyLlamaTests/LLMConfigTests.swift`

**Step 1: Write failing tests**

Create `HeyLlamaTests/LLMConfigTests.swift`:

```swift
import XCTest
@testable import HeyLlama

final class LLMConfigTests: XCTestCase {

    func testLLMProviderCases() {
        XCTAssertEqual(LLMProvider.appleIntelligence.rawValue, "appleIntelligence")
        XCTAssertEqual(LLMProvider.openAICompatible.rawValue, "openAICompatible")
    }

    func testLLMProviderCodable() throws {
        let provider = LLMProvider.openAICompatible
        let data = try JSONEncoder().encode(provider)
        let decoded = try JSONDecoder().decode(LLMProvider.self, from: data)
        XCTAssertEqual(decoded, provider)
    }

    func testAppleIntelligenceConfigDefaults() {
        let config = AppleIntelligenceConfig()
        XCTAssertTrue(config.enabled)
        XCTAssertNil(config.preferredModel)
    }

    func testOpenAICompatibleConfigDefaults() {
        let config = OpenAICompatibleConfig()
        XCTAssertTrue(config.enabled)
        XCTAssertEqual(config.baseURL, "http://localhost:11434/v1")
        XCTAssertNil(config.apiKey)
        XCTAssertEqual(config.model, "")
        XCTAssertEqual(config.timeoutSeconds, 60)
    }

    func testOpenAICompatibleConfigIsConfigured() {
        var config = OpenAICompatibleConfig()

        // Empty model = not configured
        XCTAssertFalse(config.isConfigured)

        // With model = configured
        config.model = "llama3.2"
        XCTAssertTrue(config.isConfigured)

        // Empty baseURL = not configured
        config.baseURL = ""
        XCTAssertFalse(config.isConfigured)
    }

    func testLLMConfigDefaults() {
        let config = LLMConfig.default
        XCTAssertEqual(config.provider, .appleIntelligence)
        XCTAssertTrue(config.systemPrompt.contains("Llama"))
        XCTAssertEqual(config.conversationTimeoutMinutes, 5)
        XCTAssertEqual(config.maxConversationTurns, 10)
    }

    func testLLMConfigSystemPromptContainsSpeakerPlaceholder() {
        let config = LLMConfig.default
        XCTAssertTrue(config.systemPrompt.contains("{speaker_name}"))
    }

    func testLLMConfigCodable() throws {
        var config = LLMConfig.default
        config.provider = .openAICompatible
        config.openAICompatible.model = "gpt-4"
        config.openAICompatible.apiKey = "test-key"

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(config)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(LLMConfig.self, from: data)

        XCTAssertEqual(decoded.provider, .openAICompatible)
        XCTAssertEqual(decoded.openAICompatible.model, "gpt-4")
        XCTAssertEqual(decoded.openAICompatible.apiKey, "test-key")
    }
}
```

**Step 2: Run tests to verify they fail**

In Xcode: Open Test Navigator (`Cmd+6`), find `LLMConfigTests`, click the diamond to run.

Expected: Compilation error - `LLMProvider`, `LLMConfig` not found

**Step 3: Implement LLMConfig**

Create `HeyLlama/Storage/LLMConfig.swift`:

```swift
import Foundation

/// LLM provider selection
enum LLMProvider: String, Codable, CaseIterable, Sendable {
    case appleIntelligence
    case openAICompatible
}

/// Apple Intelligence configuration
struct AppleIntelligenceConfig: Codable, Equatable, Sendable {
    var enabled: Bool
    var preferredModel: String?

    init(enabled: Bool = true, preferredModel: String? = nil) {
        self.enabled = enabled
        self.preferredModel = preferredModel
    }
}

/// OpenAI-compatible API configuration (Ollama, LM Studio, etc.)
struct OpenAICompatibleConfig: Codable, Equatable, Sendable {
    var enabled: Bool
    var baseURL: String
    var apiKey: String?
    var model: String
    var timeoutSeconds: Int

    init(
        enabled: Bool = true,
        baseURL: String = "http://localhost:11434/v1",
        apiKey: String? = nil,
        model: String = "",
        timeoutSeconds: Int = 60
    ) {
        self.enabled = enabled
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.model = model
        self.timeoutSeconds = timeoutSeconds
    }

    /// Returns true if minimum configuration is set (baseURL + model)
    var isConfigured: Bool {
        !baseURL.isEmpty && !model.isEmpty
    }
}

/// Complete LLM configuration
struct LLMConfig: Codable, Equatable, Sendable {
    var provider: LLMProvider
    var systemPrompt: String
    var appleIntelligence: AppleIntelligenceConfig
    var openAICompatible: OpenAICompatibleConfig
    var conversationTimeoutMinutes: Int
    var maxConversationTurns: Int

    static let defaultSystemPrompt = """
        You are Llama, a helpful voice assistant. Keep responses concise \
        and conversational, suitable for reading on a small UI display. \
        The current user is {speaker_name}. Be friendly but brief.
        """

    init(
        provider: LLMProvider = .appleIntelligence,
        systemPrompt: String = LLMConfig.defaultSystemPrompt,
        appleIntelligence: AppleIntelligenceConfig = AppleIntelligenceConfig(),
        openAICompatible: OpenAICompatibleConfig = OpenAICompatibleConfig(),
        conversationTimeoutMinutes: Int = 5,
        maxConversationTurns: Int = 10
    ) {
        self.provider = provider
        self.systemPrompt = systemPrompt
        self.appleIntelligence = appleIntelligence
        self.openAICompatible = openAICompatible
        self.conversationTimeoutMinutes = conversationTimeoutMinutes
        self.maxConversationTurns = maxConversationTurns
    }

    static var `default`: LLMConfig {
        LLMConfig()
    }
}
```

**Step 4: Run tests to verify they pass**

In Xcode: Run `LLMConfigTests` via Test Navigator (`Cmd+6`) or press `Cmd+U` for all tests.

Expected: All tests pass (green checkmarks)

**Step 5: Commit**

```bash
git add HeyLlama/Storage/LLMConfig.swift HeyLlamaTests/LLMConfigTests.swift
git commit -m "feat(config): add LLMConfig and LLMProvider models"
```

---

## Task 2: AssistantConfig with LLM Settings

**Files:**
- Create: `HeyLlama/Storage/AssistantConfig.swift`
- Test: `HeyLlamaTests/AssistantConfigTests.swift`

**Step 1: Write failing tests**

Create `HeyLlamaTests/AssistantConfigTests.swift`:

```swift
import XCTest
@testable import HeyLlama

final class AssistantConfigTests: XCTestCase {

    func testAssistantConfigDefaults() {
        let config = AssistantConfig.default
        XCTAssertEqual(config.wakePhrase, "hey llama")
        XCTAssertEqual(config.wakeWordSensitivity, 0.5)
        XCTAssertEqual(config.apiPort, 8765)
        XCTAssertTrue(config.apiEnabled)
    }

    func testAssistantConfigHasLLMConfig() {
        let config = AssistantConfig.default
        XCTAssertEqual(config.llm.provider, .appleIntelligence)
    }

    func testAssistantConfigCodable() throws {
        var config = AssistantConfig.default
        config.wakePhrase = "ok computer"
        config.llm.provider = .openAICompatible
        config.llm.openAICompatible.model = "llama3.2"

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(config)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AssistantConfig.self, from: data)

        XCTAssertEqual(decoded.wakePhrase, "ok computer")
        XCTAssertEqual(decoded.llm.provider, .openAICompatible)
        XCTAssertEqual(decoded.llm.openAICompatible.model, "llama3.2")
    }

    func testAssistantConfigEquatable() {
        let config1 = AssistantConfig.default
        let config2 = AssistantConfig.default
        XCTAssertEqual(config1, config2)

        var config3 = AssistantConfig.default
        config3.wakePhrase = "different"
        XCTAssertNotEqual(config1, config3)
    }
}
```

**Step 2: Run tests to verify they fail**

In Xcode: Open Test Navigator (`Cmd+6`), find `AssistantConfigTests`, click the diamond to run.

Expected: Compilation error - `AssistantConfig` not found

**Step 3: Implement AssistantConfig**

Create `HeyLlama/Storage/AssistantConfig.swift`:

```swift
import Foundation

/// Main configuration for the assistant
struct AssistantConfig: Codable, Equatable, Sendable {
    var wakePhrase: String
    var wakeWordSensitivity: Float
    var apiPort: UInt16
    var apiEnabled: Bool
    var llm: LLMConfig

    init(
        wakePhrase: String = "hey llama",
        wakeWordSensitivity: Float = 0.5,
        apiPort: UInt16 = 8765,
        apiEnabled: Bool = true,
        llm: LLMConfig = .default
    ) {
        self.wakePhrase = wakePhrase
        self.wakeWordSensitivity = wakeWordSensitivity
        self.apiPort = apiPort
        self.apiEnabled = apiEnabled
        self.llm = llm
    }

    static var `default`: AssistantConfig {
        AssistantConfig()
    }
}
```

**Step 4: Run tests to verify they pass**

In Xcode: Run `AssistantConfigTests` via Test Navigator (`Cmd+6`) or press `Cmd+U` for all tests.

Expected: All tests pass (green checkmarks)

**Step 5: Commit**

```bash
git add HeyLlama/Storage/AssistantConfig.swift HeyLlamaTests/AssistantConfigTests.swift
git commit -m "feat(config): add AssistantConfig with LLM settings"
```

---

## Task 3: ConfigStore for Persistence

**Files:**
- Create: `HeyLlama/Storage/ConfigStore.swift`
- Test: `HeyLlamaTests/ConfigStoreTests.swift`

**Step 1: Write failing tests**

Create `HeyLlamaTests/ConfigStoreTests.swift`:

```swift
import XCTest
@testable import HeyLlama

final class ConfigStoreTests: XCTestCase {

    var tempDirectory: URL!
    var configStore: ConfigStore!

    override func setUp() {
        super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(
            at: tempDirectory,
            withIntermediateDirectories: true
        )
        configStore = ConfigStore(baseDirectory: tempDirectory)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDirectory)
        super.tearDown()
    }

    func testLoadConfigReturnsDefaultWhenNoFile() {
        let config = configStore.loadConfig()
        XCTAssertEqual(config.wakePhrase, "hey llama")
        XCTAssertEqual(config.llm.provider, .appleIntelligence)
    }

    func testSaveAndLoadConfig() throws {
        var config = AssistantConfig.default
        config.wakePhrase = "ok computer"
        config.llm.provider = .openAICompatible
        config.llm.openAICompatible.model = "llama3.2"
        config.llm.openAICompatible.baseURL = "http://localhost:11434/v1"

        try configStore.saveConfig(config)
        let loaded = configStore.loadConfig()

        XCTAssertEqual(loaded.wakePhrase, "ok computer")
        XCTAssertEqual(loaded.llm.provider, .openAICompatible)
        XCTAssertEqual(loaded.llm.openAICompatible.model, "llama3.2")
    }

    func testConfigFileLocation() {
        let expectedPath = tempDirectory.appendingPathComponent("config.json")
        XCTAssertEqual(configStore.configFileURL, expectedPath)
    }

    func testSaveCreatesFile() throws {
        let config = AssistantConfig.default
        try configStore.saveConfig(config)

        XCTAssertTrue(FileManager.default.fileExists(atPath: configStore.configFileURL.path))
    }

    func testLoadConfigHandlesCorruptFile() throws {
        // Write invalid JSON
        let invalidData = "not valid json".data(using: .utf8)!
        try invalidData.write(to: configStore.configFileURL)

        // Should return default config
        let config = configStore.loadConfig()
        XCTAssertEqual(config.wakePhrase, "hey llama")
    }
}
```

**Step 2: Run tests to verify they fail**

In Xcode: Open Test Navigator (`Cmd+6`), find `ConfigStoreTests`, click the diamond to run.

Expected: Compilation error - `ConfigStore` not found

**Step 3: Implement ConfigStore**

Create `HeyLlama/Storage/ConfigStore.swift`:

```swift
import Foundation

/// Storage for assistant configuration, persisted as JSON
final class ConfigStore: Sendable {
    let configFileURL: URL

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        return decoder
    }()

    init(baseDirectory: URL? = nil) {
        let directory: URL

        if let baseDirectory = baseDirectory {
            directory = baseDirectory
        } else {
            let appSupport = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            )[0]
            directory = appSupport.appendingPathComponent("HeyLlama", isDirectory: true)
        }

        // Ensure directory exists
        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        self.configFileURL = directory.appendingPathComponent("config.json")
    }

    func loadConfig() -> AssistantConfig {
        guard FileManager.default.fileExists(atPath: configFileURL.path) else {
            return .default
        }

        do {
            let data = try Data(contentsOf: configFileURL)
            return try decoder.decode(AssistantConfig.self, from: data)
        } catch {
            print("Failed to load config: \(error)")
            return .default
        }
    }

    func saveConfig(_ config: AssistantConfig) throws {
        let data = try encoder.encode(config)
        try data.write(to: configFileURL, options: .atomic)
    }
}
```

**Step 4: Run tests to verify they pass**

In Xcode: Run `ConfigStoreTests` via Test Navigator (`Cmd+6`) or press `Cmd+U` for all tests.

Expected: All tests pass (green checkmarks)

**Step 5: Commit**

```bash
git add HeyLlama/Storage/ConfigStore.swift HeyLlamaTests/ConfigStoreTests.swift
git commit -m "feat(storage): add ConfigStore for persisting AssistantConfig"
```

---

## Task 4: ConversationManager for Multi-Turn Context

**Files:**
- Create: `HeyLlama/Core/ConversationManager.swift`
- Test: `HeyLlamaTests/ConversationManagerTests.swift`

**Step 1: Write failing tests**

Create `HeyLlamaTests/ConversationManagerTests.swift`:

```swift
import XCTest
@testable import HeyLlama

final class ConversationManagerTests: XCTestCase {

    func testAddTurnAndGetHistory() {
        let manager = ConversationManager(timeoutMinutes: 5, maxTurns: 10)

        manager.addTurn(role: .user, content: "What's the capital of France?")
        manager.addTurn(role: .assistant, content: "Paris")

        let history = manager.getRecentHistory()
        XCTAssertEqual(history.count, 2)
        XCTAssertEqual(history[0].role, .user)
        XCTAssertEqual(history[0].content, "What's the capital of France?")
        XCTAssertEqual(history[1].role, .assistant)
        XCTAssertEqual(history[1].content, "Paris")
    }

    func testMaxTurnsLimit() {
        let manager = ConversationManager(timeoutMinutes: 5, maxTurns: 3)

        manager.addTurn(role: .user, content: "One")
        manager.addTurn(role: .assistant, content: "Two")
        manager.addTurn(role: .user, content: "Three")
        manager.addTurn(role: .assistant, content: "Four")

        let history = manager.getRecentHistory()
        // Should only keep last 3 turns
        XCTAssertEqual(history.count, 3)
        XCTAssertEqual(history[0].content, "Two")
        XCTAssertEqual(history[1].content, "Three")
        XCTAssertEqual(history[2].content, "Four")
    }

    func testTimeoutPruning() {
        let manager = ConversationManager(timeoutMinutes: 1, maxTurns: 10)

        // Add a turn with an old timestamp
        let oldTurn = ConversationTurn(
            role: .user,
            content: "Old message",
            timestamp: Date().addingTimeInterval(-120) // 2 minutes ago
        )
        manager.addTurnDirectly(oldTurn)

        // Add a recent turn
        manager.addTurn(role: .user, content: "Recent message")

        let history = manager.getRecentHistory()
        // Old turn should be pruned
        XCTAssertEqual(history.count, 1)
        XCTAssertEqual(history[0].content, "Recent message")
    }

    func testClearHistory() {
        let manager = ConversationManager(timeoutMinutes: 5, maxTurns: 10)

        manager.addTurn(role: .user, content: "Hello")
        manager.addTurn(role: .assistant, content: "Hi!")

        manager.clearHistory()

        let history = manager.getRecentHistory()
        XCTAssertTrue(history.isEmpty)
    }

    func testEmptyHistoryReturnsEmptyArray() {
        let manager = ConversationManager(timeoutMinutes: 5, maxTurns: 10)
        let history = manager.getRecentHistory()
        XCTAssertTrue(history.isEmpty)
    }

    func testHasRecentHistory() {
        let manager = ConversationManager(timeoutMinutes: 5, maxTurns: 10)

        XCTAssertFalse(manager.hasRecentHistory())

        manager.addTurn(role: .user, content: "Hello")
        XCTAssertTrue(manager.hasRecentHistory())

        manager.clearHistory()
        XCTAssertFalse(manager.hasRecentHistory())
    }
}
```

**Step 2: Run tests to verify they fail**

In Xcode: Open Test Navigator (`Cmd+6`), find `ConversationManagerTests`, click the diamond to run.

Expected: Compilation error - `ConversationManager` not found

**Step 3: Update ConversationTurn to support custom timestamps**

Modify `HeyLlama/Models/Command.swift` to add initializer with timestamp:

Add this initializer to `ConversationTurn`:

```swift
struct ConversationTurn: Sendable {
    let role: ConversationRole
    let content: String
    let timestamp: Date

    init(role: ConversationRole, content: String) {
        self.role = role
        self.content = content
        self.timestamp = Date()
    }

    // New initializer for testing with custom timestamp
    init(role: ConversationRole, content: String, timestamp: Date) {
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }
}
```

**Step 4: Implement ConversationManager**

Create `HeyLlama/Core/ConversationManager.swift`:

```swift
import Foundation

/// Manages conversation history with time-based windowing
final class ConversationManager: @unchecked Sendable {
    private var turns: [ConversationTurn] = []
    private let lock = NSLock()

    private let timeoutMinutes: Int
    private let maxTurns: Int

    init(timeoutMinutes: Int = 5, maxTurns: Int = 10) {
        self.timeoutMinutes = timeoutMinutes
        self.maxTurns = maxTurns
    }

    /// Add a new conversation turn
    func addTurn(role: ConversationRole, content: String) {
        let turn = ConversationTurn(role: role, content: content)
        addTurnDirectly(turn)
    }

    /// Add a turn directly (used for testing with custom timestamps)
    func addTurnDirectly(_ turn: ConversationTurn) {
        lock.lock()
        defer { lock.unlock() }

        turns.append(turn)
        pruneOldTurns()
    }

    /// Get recent conversation history within the time window
    func getRecentHistory() -> [ConversationTurn] {
        lock.lock()
        defer { lock.unlock() }

        pruneOldTurns()
        return turns
    }

    /// Check if there's any recent conversation history
    func hasRecentHistory() -> Bool {
        lock.lock()
        defer { lock.unlock() }

        pruneOldTurns()
        return !turns.isEmpty
    }

    /// Clear all conversation history
    func clearHistory() {
        lock.lock()
        defer { lock.unlock() }

        turns.removeAll()
    }

    /// Prune turns that are older than the timeout or exceed max turns
    private func pruneOldTurns() {
        let cutoff = Date().addingTimeInterval(-Double(timeoutMinutes * 60))

        // Remove turns older than timeout
        turns = turns.filter { $0.timestamp > cutoff }

        // Keep only the most recent maxTurns
        if turns.count > maxTurns {
            turns = Array(turns.suffix(maxTurns))
        }
    }
}
```

**Step 5: Run tests to verify they pass**

In Xcode: Run `ConversationManagerTests` via Test Navigator (`Cmd+6`) or press `Cmd+U` for all tests.

Expected: All tests pass (green checkmarks)

**Step 6: Commit**

```bash
git add HeyLlama/Core/ConversationManager.swift HeyLlama/Models/Command.swift HeyLlamaTests/ConversationManagerTests.swift
git commit -m "feat(core): add ConversationManager for multi-turn context"
```

---

## Task 5: LLMServiceProtocol and LLMError

**Files:**
- Create: `HeyLlama/Services/LLM/LLMServiceProtocol.swift`
- Test: `HeyLlamaTests/LLMServiceProtocolTests.swift`

**Step 1: Write failing tests**

Create `HeyLlamaTests/LLMServiceProtocolTests.swift`:

```swift
import XCTest
@testable import HeyLlama

final class LLMServiceProtocolTests: XCTestCase {

    func testLLMErrorDescriptions() {
        let notConfigured = LLMError.notConfigured
        XCTAssertTrue(notConfigured.localizedDescription.contains("not configured"))

        let networkError = LLMError.networkError("Connection refused")
        XCTAssertTrue(networkError.localizedDescription.contains("Connection refused"))

        let apiError = LLMError.apiError(statusCode: 401, message: "Unauthorized")
        XCTAssertTrue(apiError.localizedDescription.contains("401"))
        XCTAssertTrue(apiError.localizedDescription.contains("Unauthorized"))

        let parseError = LLMError.responseParseError("Invalid JSON")
        XCTAssertTrue(parseError.localizedDescription.contains("Invalid JSON"))

        let unavailable = LLMError.providerUnavailable("Apple Intelligence not supported")
        XCTAssertTrue(unavailable.localizedDescription.contains("not supported"))
    }

    func testLLMErrorEquatable() {
        XCTAssertEqual(LLMError.notConfigured, LLMError.notConfigured)
        XCTAssertNotEqual(LLMError.notConfigured, LLMError.networkError("test"))
    }
}
```

**Step 2: Run tests to verify they fail**

In Xcode: Open Test Navigator (`Cmd+6`), find `LLMServiceProtocolTests`, click the diamond to run.

Expected: Compilation error - `LLMError` not found

**Step 3: Implement LLMServiceProtocol**

Create `HeyLlama/Services/LLM/LLMServiceProtocol.swift`:

```swift
import Foundation

/// Errors that can occur during LLM operations
enum LLMError: Error, Equatable, LocalizedError {
    case notConfigured
    case networkError(String)
    case apiError(statusCode: Int, message: String)
    case responseParseError(String)
    case providerUnavailable(String)
    case timeout

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "LLM provider is not configured"
        case .networkError(let message):
            return "Network error: \(message)"
        case .apiError(let statusCode, let message):
            return "API error (\(statusCode)): \(message)"
        case .responseParseError(let message):
            return "Failed to parse response: \(message)"
        case .providerUnavailable(let message):
            return "Provider unavailable: \(message)"
        case .timeout:
            return "Request timed out"
        }
    }
}

/// Protocol for LLM service implementations
protocol LLMServiceProtocol: Sendable {
    /// Whether the service is properly configured and ready to use
    var isConfigured: Bool { get async }

    /// Complete a prompt with optional conversation context
    /// - Parameters:
    ///   - prompt: The user's command/question
    ///   - context: Optional command context including speaker info
    ///   - conversationHistory: Previous conversation turns for multi-turn context
    /// - Returns: The LLM's response text
    func complete(
        prompt: String,
        context: CommandContext?,
        conversationHistory: [ConversationTurn]
    ) async throws -> String
}

/// Extension with convenience method
extension LLMServiceProtocol {
    func complete(prompt: String, context: CommandContext?) async throws -> String {
        try await complete(prompt: prompt, context: context, conversationHistory: [])
    }
}
```

**Step 4: Run tests to verify they pass**

In Xcode: Run `LLMServiceProtocolTests` via Test Navigator (`Cmd+6`) or press `Cmd+U` for all tests.

Expected: All tests pass (green checkmarks)

**Step 5: Commit**

```bash
git add HeyLlama/Services/LLM/LLMServiceProtocol.swift HeyLlamaTests/LLMServiceProtocolTests.swift
git commit -m "feat(llm): add LLMServiceProtocol and LLMError types"
```

---

## Task 6: MockLLMService for Testing

**Files:**
- Create: `HeyLlamaTests/Mocks/MockLLMService.swift`
- Test: `HeyLlamaTests/MockLLMServiceTests.swift`

**Step 1: Write failing tests**

Create `HeyLlamaTests/MockLLMServiceTests.swift`:

```swift
import XCTest
@testable import HeyLlama

final class MockLLMServiceTests: XCTestCase {

    func testIsConfiguredDefault() async {
        let mock = MockLLMService()
        let configured = await mock.isConfigured
        XCTAssertTrue(configured)
    }

    func testSetNotConfigured() async {
        let mock = MockLLMService()
        await mock.setConfigured(false)
        let configured = await mock.isConfigured
        XCTAssertFalse(configured)
    }

    func testCompletionReturnsMockResponse() async throws {
        let mock = MockLLMService()
        await mock.setMockResponse("The time is 3:30 PM")

        let response = try await mock.complete(prompt: "What time is it?", context: nil)
        XCTAssertEqual(response, "The time is 3:30 PM")
    }

    func testCompletionTracksLastPrompt() async throws {
        let mock = MockLLMService()
        await mock.setMockResponse("Response")

        _ = try await mock.complete(prompt: "Test prompt", context: nil)

        let lastPrompt = await mock.lastPrompt
        XCTAssertEqual(lastPrompt, "Test prompt")
    }

    func testCompletionTracksContext() async throws {
        let mock = MockLLMService()
        await mock.setMockResponse("Response")

        let context = CommandContext(command: "test", source: .localMic)
        _ = try await mock.complete(prompt: "Test", context: context)

        let lastContext = await mock.lastContext
        XCTAssertEqual(lastContext?.command, "test")
    }

    func testCompletionTracksConversationHistory() async throws {
        let mock = MockLLMService()
        await mock.setMockResponse("Response")

        let history = [
            ConversationTurn(role: .user, content: "Hello"),
            ConversationTurn(role: .assistant, content: "Hi!")
        ]

        _ = try await mock.complete(prompt: "Test", context: nil, conversationHistory: history)

        let lastHistory = await mock.lastConversationHistory
        XCTAssertEqual(lastHistory.count, 2)
    }

    func testCompletionThrowsMockError() async {
        let mock = MockLLMService()
        await mock.setMockError(LLMError.notConfigured)

        do {
            _ = try await mock.complete(prompt: "Test", context: nil)
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertEqual(error as? LLMError, .notConfigured)
        }
    }

    func testCompletionCountTracking() async throws {
        let mock = MockLLMService()
        await mock.setMockResponse("Response")

        _ = try await mock.complete(prompt: "One", context: nil)
        _ = try await mock.complete(prompt: "Two", context: nil)
        _ = try await mock.complete(prompt: "Three", context: nil)

        let count = await mock.completionCount
        XCTAssertEqual(count, 3)
    }

    func testResetCallTracking() async throws {
        let mock = MockLLMService()
        await mock.setMockResponse("Response")

        _ = try await mock.complete(prompt: "Test", context: nil)

        await mock.resetCallTracking()

        let count = await mock.completionCount
        let lastPrompt = await mock.lastPrompt

        XCTAssertEqual(count, 0)
        XCTAssertNil(lastPrompt)
    }
}
```

**Step 2: Run tests to verify they fail**

In Xcode: Open Test Navigator (`Cmd+6`), find `MockLLMServiceTests`, click the diamond to run.

Expected: Compilation error - `MockLLMService` not found

**Step 3: Implement MockLLMService**

Create `HeyLlamaTests/Mocks/MockLLMService.swift`:

```swift
import Foundation
@testable import HeyLlama

actor MockLLMService: LLMServiceProtocol {
    private var _isConfigured: Bool = true
    private var mockResponse: String = ""
    private var mockError: Error?

    private(set) var lastPrompt: String?
    private(set) var lastContext: CommandContext?
    private(set) var lastConversationHistory: [ConversationTurn] = []
    private(set) var completionCount: Int = 0

    var isConfigured: Bool {
        _isConfigured
    }

    func setConfigured(_ configured: Bool) {
        _isConfigured = configured
    }

    func setMockResponse(_ response: String) {
        self.mockResponse = response
        self.mockError = nil
    }

    func setMockError(_ error: Error) {
        self.mockError = error
    }

    func complete(
        prompt: String,
        context: CommandContext?,
        conversationHistory: [ConversationTurn]
    ) async throws -> String {
        lastPrompt = prompt
        lastContext = context
        lastConversationHistory = conversationHistory
        completionCount += 1

        if let error = mockError {
            throw error
        }

        return mockResponse
    }

    func resetCallTracking() {
        lastPrompt = nil
        lastContext = nil
        lastConversationHistory = []
        completionCount = 0
    }
}
```

**Step 4: Run tests to verify they pass**

In Xcode: Run `MockLLMServiceTests` via Test Navigator (`Cmd+6`) or press `Cmd+U` for all tests.

Expected: All tests pass (green checkmarks)

**Step 5: Commit**

```bash
git add HeyLlamaTests/Mocks/MockLLMService.swift HeyLlamaTests/MockLLMServiceTests.swift
git commit -m "test(llm): add MockLLMService for testing"
```

---

## Task 7: OpenAI-Compatible Provider Implementation

**Files:**
- Create: `HeyLlama/Services/LLM/LLMProviders/OpenAICompatibleProvider.swift`
- Test: `HeyLlamaTests/OpenAICompatibleProviderTests.swift`

**Step 1: Write failing tests**

Create `HeyLlamaTests/OpenAICompatibleProviderTests.swift`:

```swift
import XCTest
@testable import HeyLlama

final class OpenAICompatibleProviderTests: XCTestCase {

    func testIsConfiguredWhenModelSet() async {
        var config = OpenAICompatibleConfig()
        config.model = "llama3.2"
        config.baseURL = "http://localhost:11434/v1"

        let provider = OpenAICompatibleProvider(config: config)
        let configured = await provider.isConfigured
        XCTAssertTrue(configured)
    }

    func testIsNotConfiguredWhenModelEmpty() async {
        var config = OpenAICompatibleConfig()
        config.model = ""
        config.baseURL = "http://localhost:11434/v1"

        let provider = OpenAICompatibleProvider(config: config)
        let configured = await provider.isConfigured
        XCTAssertFalse(configured)
    }

    func testIsNotConfiguredWhenBaseURLEmpty() async {
        var config = OpenAICompatibleConfig()
        config.model = "llama3.2"
        config.baseURL = ""

        let provider = OpenAICompatibleProvider(config: config)
        let configured = await provider.isConfigured
        XCTAssertFalse(configured)
    }

    func testBuildRequestBodyWithoutHistory() throws {
        var config = OpenAICompatibleConfig()
        config.model = "llama3.2"

        let provider = OpenAICompatibleProvider(config: config)
        let body = provider.buildRequestBody(
            systemPrompt: "You are helpful.",
            prompt: "What time is it?",
            conversationHistory: []
        )

        // Verify structure
        XCTAssertEqual(body["model"] as? String, "llama3.2")

        let messages = body["messages"] as? [[String: String]]
        XCTAssertNotNil(messages)
        XCTAssertEqual(messages?.count, 2) // system + user

        XCTAssertEqual(messages?[0]["role"], "system")
        XCTAssertEqual(messages?[0]["content"], "You are helpful.")

        XCTAssertEqual(messages?[1]["role"], "user")
        XCTAssertEqual(messages?[1]["content"], "What time is it?")
    }

    func testBuildRequestBodyWithHistory() throws {
        var config = OpenAICompatibleConfig()
        config.model = "llama3.2"

        let provider = OpenAICompatibleProvider(config: config)

        let history = [
            ConversationTurn(role: .user, content: "Capital of France?"),
            ConversationTurn(role: .assistant, content: "Paris")
        ]

        let body = provider.buildRequestBody(
            systemPrompt: "You are helpful.",
            prompt: "What language there?",
            conversationHistory: history
        )

        let messages = body["messages"] as? [[String: String]]
        XCTAssertNotNil(messages)
        XCTAssertEqual(messages?.count, 5) // system + 2 history + user

        // Verify order: system, history, current prompt
        XCTAssertEqual(messages?[0]["role"], "system")
        XCTAssertEqual(messages?[1]["role"], "user")
        XCTAssertEqual(messages?[1]["content"], "Capital of France?")
        XCTAssertEqual(messages?[2]["role"], "assistant")
        XCTAssertEqual(messages?[2]["content"], "Paris")
        XCTAssertEqual(messages?[3]["role"], "user")
        XCTAssertEqual(messages?[3]["content"], "What language there?")
    }

    func testBuildSystemPromptWithSpeakerName() {
        let config = OpenAICompatibleConfig()
        let provider = OpenAICompatibleProvider(config: config)

        let template = "Hello {speaker_name}, how can I help?"
        let result = provider.buildSystemPrompt(template: template, speakerName: "Alice")

        XCTAssertEqual(result, "Hello Alice, how can I help?")
    }

    func testBuildSystemPromptWithGuestWhenNil() {
        let config = OpenAICompatibleConfig()
        let provider = OpenAICompatibleProvider(config: config)

        let template = "Hello {speaker_name}, how can I help?"
        let result = provider.buildSystemPrompt(template: template, speakerName: nil)

        XCTAssertEqual(result, "Hello Guest, how can I help?")
    }

    func testParseResponseExtractsContent() throws {
        let config = OpenAICompatibleConfig()
        let provider = OpenAICompatibleProvider(config: config)

        let responseJSON = """
        {
            "id": "chatcmpl-123",
            "choices": [{
                "index": 0,
                "message": {
                    "role": "assistant",
                    "content": "The time is 3:30 PM."
                },
                "finish_reason": "stop"
            }]
        }
        """

        let data = responseJSON.data(using: .utf8)!
        let content = try provider.parseResponse(data)

        XCTAssertEqual(content, "The time is 3:30 PM.")
    }

    func testParseResponseThrowsOnInvalidJSON() {
        let config = OpenAICompatibleConfig()
        let provider = OpenAICompatibleProvider(config: config)

        let invalidData = "not json".data(using: .utf8)!

        XCTAssertThrowsError(try provider.parseResponse(invalidData)) { error in
            XCTAssertTrue(error is LLMError)
        }
    }

    func testParseResponseThrowsOnMissingChoices() {
        let config = OpenAICompatibleConfig()
        let provider = OpenAICompatibleProvider(config: config)

        let responseJSON = """
        {
            "id": "chatcmpl-123",
            "choices": []
        }
        """

        let data = responseJSON.data(using: .utf8)!

        XCTAssertThrowsError(try provider.parseResponse(data)) { error in
            XCTAssertTrue(error is LLMError)
        }
    }
}
```

**Step 2: Run tests to verify they fail**

In Xcode: Open Test Navigator (`Cmd+6`), find `OpenAICompatibleProviderTests`, click the diamond to run.

Expected: Compilation error - `OpenAICompatibleProvider` not found

**Step 3: Implement OpenAICompatibleProvider**

Create `HeyLlama/Services/LLM/LLMProviders/OpenAICompatibleProvider.swift`:

```swift
import Foundation

/// OpenAI-compatible API provider (works with Ollama, LM Studio, etc.)
actor OpenAICompatibleProvider: LLMServiceProtocol {
    private let config: OpenAICompatibleConfig
    private let systemPromptTemplate: String
    private let urlSession: URLSession

    var isConfigured: Bool {
        config.isConfigured
    }

    init(config: OpenAICompatibleConfig, systemPromptTemplate: String = LLMConfig.defaultSystemPrompt) {
        self.config = config
        self.systemPromptTemplate = systemPromptTemplate

        // Configure URLSession with timeout
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = TimeInterval(config.timeoutSeconds)
        configuration.timeoutIntervalForResource = TimeInterval(config.timeoutSeconds)
        self.urlSession = URLSession(configuration: configuration)
    }

    func complete(
        prompt: String,
        context: CommandContext?,
        conversationHistory: [ConversationTurn]
    ) async throws -> String {
        guard isConfigured else {
            throw LLMError.notConfigured
        }

        // Build the request
        let url = try buildURL()
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Add API key header if provided
        if let apiKey = config.apiKey, !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        // Build system prompt with speaker name
        let speakerName = context?.speaker?.name
        let systemPrompt = buildSystemPrompt(template: systemPromptTemplate, speakerName: speakerName)

        // Build request body
        let body = buildRequestBody(
            systemPrompt: systemPrompt,
            prompt: prompt,
            conversationHistory: conversationHistory
        )

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        // Make request
        let (data, response) = try await performRequest(request)

        // Check HTTP status
        if let httpResponse = response as? HTTPURLResponse {
            guard (200...299).contains(httpResponse.statusCode) else {
                let message = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw LLMError.apiError(statusCode: httpResponse.statusCode, message: message)
            }
        }

        // Parse response
        return try parseResponse(data)
    }

    // MARK: - Internal Methods (exposed for testing)

    nonisolated func buildURL() throws -> URL {
        let baseURL = config.baseURL.trimmingCharacters(in: .init(charactersIn: "/"))
        guard let url = URL(string: "\(baseURL)/chat/completions") else {
            throw LLMError.notConfigured
        }
        return url
    }

    nonisolated func buildSystemPrompt(template: String, speakerName: String?) -> String {
        let name = speakerName ?? "Guest"
        return template.replacingOccurrences(of: "{speaker_name}", with: name)
    }

    nonisolated func buildRequestBody(
        systemPrompt: String,
        prompt: String,
        conversationHistory: [ConversationTurn]
    ) -> [String: Any] {
        var messages: [[String: String]] = []

        // System message
        messages.append([
            "role": "system",
            "content": systemPrompt
        ])

        // Conversation history
        for turn in conversationHistory {
            messages.append([
                "role": turn.role == .user ? "user" : "assistant",
                "content": turn.content
            ])
        }

        // Current user message
        messages.append([
            "role": "user",
            "content": prompt
        ])

        return [
            "model": config.model,
            "messages": messages
        ]
    }

    nonisolated func parseResponse(_ data: Data) throws -> String {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw LLMError.responseParseError("Invalid response structure")
        }

        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func performRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await urlSession.data(for: request)
        } catch let error as URLError {
            switch error.code {
            case .timedOut:
                throw LLMError.timeout
            case .notConnectedToInternet, .networkConnectionLost:
                throw LLMError.networkError("No internet connection")
            default:
                throw LLMError.networkError(error.localizedDescription)
            }
        }
    }
}
```

**Step 4: Run tests to verify they pass**

In Xcode: Run `OpenAICompatibleProviderTests` via Test Navigator (`Cmd+6`) or press `Cmd+U` for all tests.

Expected: All tests pass (green checkmarks)

**Step 5: Commit**

```bash
git add HeyLlama/Services/LLM/LLMProviders/OpenAICompatibleProvider.swift HeyLlamaTests/OpenAICompatibleProviderTests.swift
git commit -m "feat(llm): add OpenAI-compatible provider implementation"
```

---

## Task 8: Apple Intelligence Provider (Stub)

**Files:**
- Create: `HeyLlama/Services/LLM/LLMProviders/AppleIntelligenceProvider.swift`
- Test: `HeyLlamaTests/AppleIntelligenceProviderTests.swift`

**Note:** Apple Intelligence APIs are not yet publicly available for third-party apps. This implementation provides a stub that returns an appropriate error when unavailable and can be updated when Apple releases the API.

**Step 1: Write failing tests**

Create `HeyLlamaTests/AppleIntelligenceProviderTests.swift`:

```swift
import XCTest
@testable import HeyLlama

final class AppleIntelligenceProviderTests: XCTestCase {

    func testIsConfiguredWhenEnabled() async {
        let config = AppleIntelligenceConfig(enabled: true)
        let provider = AppleIntelligenceProvider(config: config)
        let configured = await provider.isConfigured
        // Currently returns false since API unavailable
        XCTAssertFalse(configured)
    }

    func testIsNotConfiguredWhenDisabled() async {
        let config = AppleIntelligenceConfig(enabled: false)
        let provider = AppleIntelligenceProvider(config: config)
        let configured = await provider.isConfigured
        XCTAssertFalse(configured)
    }

    func testCompleteThrowsUnavailable() async {
        let config = AppleIntelligenceConfig(enabled: true)
        let provider = AppleIntelligenceProvider(config: config)

        do {
            _ = try await provider.complete(prompt: "Test", context: nil, conversationHistory: [])
            XCTFail("Expected error to be thrown")
        } catch let error as LLMError {
            if case .providerUnavailable = error {
                // Expected
            } else {
                XCTFail("Expected providerUnavailable error")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testIsAvailableReturnsFalseCurrently() {
        let config = AppleIntelligenceConfig()
        let provider = AppleIntelligenceProvider(config: config)
        XCTAssertFalse(provider.isAvailable)
    }
}
```

**Step 2: Run tests to verify they fail**

In Xcode: Open Test Navigator (`Cmd+6`), find `AppleIntelligenceProviderTests`, click the diamond to run.

Expected: Compilation error - `AppleIntelligenceProvider` not found

**Step 3: Implement AppleIntelligenceProvider stub**

Create `HeyLlama/Services/LLM/LLMProviders/AppleIntelligenceProvider.swift`:

```swift
import Foundation

/// Apple Intelligence provider (stub - awaiting public API)
///
/// This provider will integrate with Apple's on-device AI when the API becomes
/// available for third-party developers. For now, it returns unavailable status.
actor AppleIntelligenceProvider: LLMServiceProtocol {
    private let config: AppleIntelligenceConfig
    private let systemPromptTemplate: String

    /// Check if Apple Intelligence is available on this device
    /// This will be updated when Apple releases the public API
    nonisolated var isAvailable: Bool {
        // TODO: Check for macOS version and device capability
        // For now, always return false as API is not yet available
        return false
    }

    var isConfigured: Bool {
        config.enabled && isAvailable
    }

    init(config: AppleIntelligenceConfig, systemPromptTemplate: String = LLMConfig.defaultSystemPrompt) {
        self.config = config
        self.systemPromptTemplate = systemPromptTemplate
    }

    func complete(
        prompt: String,
        context: CommandContext?,
        conversationHistory: [ConversationTurn]
    ) async throws -> String {
        guard config.enabled else {
            throw LLMError.notConfigured
        }

        guard isAvailable else {
            throw LLMError.providerUnavailable(
                "Apple Intelligence is not yet available. " +
                "Please configure an OpenAI-compatible provider in settings."
            )
        }

        // TODO: Implement actual Apple Intelligence API call when available
        // This will use Foundation.LanguageModel or similar API

        throw LLMError.providerUnavailable("Apple Intelligence API not implemented")
    }
}
```

**Step 4: Run tests to verify they pass**

In Xcode: Run `AppleIntelligenceProviderTests` via Test Navigator (`Cmd+6`) or press `Cmd+U` for all tests.

Expected: All tests pass (green checkmarks)

**Step 5: Commit**

```bash
git add HeyLlama/Services/LLM/LLMProviders/AppleIntelligenceProvider.swift HeyLlamaTests/AppleIntelligenceProviderTests.swift
git commit -m "feat(llm): add Apple Intelligence provider stub"
```

---

## Task 9: LLMService Facade

**Files:**
- Create: `HeyLlama/Services/LLM/LLMService.swift`
- Test: `HeyLlamaTests/LLMServiceTests.swift`

**Step 1: Write failing tests**

Create `HeyLlamaTests/LLMServiceTests.swift`:

```swift
import XCTest
@testable import HeyLlama

final class LLMServiceTests: XCTestCase {

    func testIsConfiguredWithOpenAIProvider() async {
        var config = LLMConfig.default
        config.provider = .openAICompatible
        config.openAICompatible.model = "llama3.2"
        config.openAICompatible.baseURL = "http://localhost:11434/v1"

        let service = LLMService(config: config)
        let configured = await service.isConfigured
        XCTAssertTrue(configured)
    }

    func testIsNotConfiguredWithEmptyOpenAI() async {
        var config = LLMConfig.default
        config.provider = .openAICompatible
        config.openAICompatible.model = ""

        let service = LLMService(config: config)
        let configured = await service.isConfigured
        XCTAssertFalse(configured)
    }

    func testIsNotConfiguredWithAppleIntelligence() async {
        // Apple Intelligence is currently unavailable
        var config = LLMConfig.default
        config.provider = .appleIntelligence

        let service = LLMService(config: config)
        let configured = await service.isConfigured
        XCTAssertFalse(configured)
    }

    func testSelectedProviderReturnsCorrectType() {
        var config = LLMConfig.default
        config.provider = .openAICompatible

        let service = LLMService(config: config)
        XCTAssertEqual(service.selectedProvider, .openAICompatible)
    }

    func testConfigProviderSwitching() async {
        var config = LLMConfig.default

        // Start with Apple Intelligence (not configured)
        config.provider = .appleIntelligence
        let service1 = LLMService(config: config)
        let configured1 = await service1.isConfigured
        XCTAssertFalse(configured1)

        // Switch to OpenAI-compatible (configured)
        config.provider = .openAICompatible
        config.openAICompatible.model = "llama3.2"
        let service2 = LLMService(config: config)
        let configured2 = await service2.isConfigured
        XCTAssertTrue(configured2)
    }
}
```

**Step 2: Run tests to verify they fail**

In Xcode: Open Test Navigator (`Cmd+6`), find `LLMServiceTests`, click the diamond to run.

Expected: Compilation error - `LLMService` not found

**Step 3: Implement LLMService**

Create `HeyLlama/Services/LLM/LLMService.swift`:

```swift
import Foundation

/// Main LLM service that delegates to the configured provider
actor LLMService: LLMServiceProtocol {
    private let config: LLMConfig
    private let appleIntelligenceProvider: AppleIntelligenceProvider
    private let openAICompatibleProvider: OpenAICompatibleProvider

    /// The currently selected provider type
    nonisolated var selectedProvider: LLMProvider {
        config.provider
    }

    var isConfigured: Bool {
        get async {
            switch config.provider {
            case .appleIntelligence:
                return await appleIntelligenceProvider.isConfigured
            case .openAICompatible:
                return await openAICompatibleProvider.isConfigured
            }
        }
    }

    init(config: LLMConfig) {
        self.config = config
        self.appleIntelligenceProvider = AppleIntelligenceProvider(
            config: config.appleIntelligence,
            systemPromptTemplate: config.systemPrompt
        )
        self.openAICompatibleProvider = OpenAICompatibleProvider(
            config: config.openAICompatible,
            systemPromptTemplate: config.systemPrompt
        )
    }

    func complete(
        prompt: String,
        context: CommandContext?,
        conversationHistory: [ConversationTurn]
    ) async throws -> String {
        switch config.provider {
        case .appleIntelligence:
            return try await appleIntelligenceProvider.complete(
                prompt: prompt,
                context: context,
                conversationHistory: conversationHistory
            )
        case .openAICompatible:
            return try await openAICompatibleProvider.complete(
                prompt: prompt,
                context: context,
                conversationHistory: conversationHistory
            )
        }
    }
}
```

**Step 4: Run tests to verify they pass**

In Xcode: Run `LLMServiceTests` via Test Navigator (`Cmd+6`) or press `Cmd+U` for all tests.

Expected: All tests pass (green checkmarks)

**Step 5: Commit**

```bash
git add HeyLlama/Services/LLM/LLMService.swift HeyLlamaTests/LLMServiceTests.swift
git commit -m "feat(llm): add LLMService facade for provider delegation"
```

---

## Task 10: Update AssistantCoordinator with LLM Integration

**Files:**
- Modify: `HeyLlama/Core/AssistantCoordinator.swift`

**Step 1: Update AssistantCoordinator to integrate LLM**

Update `HeyLlama/Core/AssistantCoordinator.swift`:

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
    @Published private(set) var lastResponse: String?
    @Published private(set) var isModelLoading: Bool = false
    @Published private(set) var currentSpeaker: Speaker?
    @Published private(set) var requiresOnboarding: Bool = true
    @Published private(set) var enrolledSpeakers: [Speaker] = []
    @Published private(set) var llmConfigured: Bool = false

    private let audioEngine: AudioEngine
    private let vadService: VADService
    private let audioBuffer: AudioBuffer
    private let sttService: any STTServiceProtocol
    private let speakerService: any SpeakerServiceProtocol
    private let llmService: any LLMServiceProtocol
    private let commandProcessor: CommandProcessor
    private let speakerStore: SpeakerStore
    private let configStore: ConfigStore
    private let conversationManager: ConversationManager
    private var cancellables = Set<AnyCancellable>()

    private var config: AssistantConfig

    init(
        sttService: (any STTServiceProtocol)? = nil,
        speakerService: (any SpeakerServiceProtocol)? = nil,
        llmService: (any LLMServiceProtocol)? = nil
    ) {
        self.configStore = ConfigStore()
        self.config = configStore.loadConfig()

        self.audioEngine = AudioEngine()
        self.vadService = VADService()
        self.audioBuffer = AudioBuffer(maxSeconds: 15)
        self.sttService = sttService ?? STTService()
        self.speakerService = speakerService ?? SpeakerService()
        self.llmService = llmService ?? LLMService(config: config.llm)
        self.commandProcessor = CommandProcessor(wakePhrase: config.wakePhrase)
        self.speakerStore = SpeakerStore()
        self.conversationManager = ConversationManager(
            timeoutMinutes: config.llm.conversationTimeoutMinutes,
            maxTurns: config.llm.maxConversationTurns
        )

        // Check if onboarding is required
        self.requiresOnboarding = !speakerStore.hasSpeakers()

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

    // MARK: - Lifecycle

    func checkOnboardingRequired() -> Bool {
        requiresOnboarding = !speakerStore.hasSpeakers()
        return requiresOnboarding
    }

    func completeOnboarding() {
        requiresOnboarding = false
    }

    func start() async {
        // Don't start if onboarding is required
        guard !requiresOnboarding else {
            print("Cannot start: onboarding required")
            return
        }

        let granted = await Permissions.requestMicrophoneAccess()

        guard granted else {
            state = .error("Microphone access denied")
            return
        }

        isModelLoading = true
        state = .idle

        // Load STT model
        do {
            try await sttService.loadModel()
        } catch {
            isModelLoading = false
            state = .error("Failed to load speech model: \(error.localizedDescription)")
            return
        }

        // Load speaker identification model
        do {
            try await speakerService.loadModel()
        } catch {
            isModelLoading = false
            state = .error("Failed to load speaker model: \(error.localizedDescription)")
            return
        }

        // Check LLM configuration
        llmConfigured = await llmService.isConfigured
        if !llmConfigured {
            print("Warning: LLM is not configured. Commands will not receive AI responses.")
        }

        isModelLoading = false

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
        lastResponse = nil
        currentSpeaker = nil
    }

    // MARK: - Configuration

    func reloadConfig() {
        config = configStore.loadConfig()
    }

    func updateLLMConfigured() async {
        llmConfigured = await llmService.isConfigured
    }

    // MARK: - Speaker Management

    func enrollSpeaker(name: String, samples: [AudioChunk]) async throws -> Speaker {
        // Ensure speaker model is loaded (needed for onboarding before start() is called)
        if await !speakerService.isModelLoaded {
            try await speakerService.loadModel()
        }

        let speaker = try await speakerService.enroll(name: name, samples: samples)
        enrolledSpeakers = await speakerService.enrolledSpeakers
        requiresOnboarding = false
        return speaker
    }

    func removeSpeaker(_ speaker: Speaker) async {
        do {
            try await speakerService.remove(speaker)
            enrolledSpeakers = await speakerService.enrolledSpeakers
            requiresOnboarding = enrolledSpeakers.isEmpty
        } catch {
            print("Failed to remove speaker: \(error)")
        }
    }

    func getEnrolledSpeakers() async -> [Speaker] {
        await speakerService.enrolledSpeakers
    }

    /// Refreshes the enrolled speakers list from the speaker service
    func refreshEnrolledSpeakers() async {
        enrolledSpeakers = await speakerService.enrolledSpeakers
    }

    // MARK: - Audio Processing

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

        // Run STT and Speaker ID in parallel
        async let transcriptionTask = sttService.transcribe(audio)
        async let speakerTask = speakerService.identify(audio)

        do {
            let (result, speaker) = try await (transcriptionTask, speakerTask)

            // Update UI with transcription and speaker
            lastTranscription = result.text
            currentSpeaker = speaker

            let speakerName = speaker?.name ?? "Guest"
            print("[Coordinator] Setting currentSpeaker to: \(speaker?.name ?? "nil") (ID: \(speaker?.id.uuidString ?? "nil"))")
            print("[\(speakerName)] Transcription: \"\(result.text)\" (confidence: \(String(format: "%.2f", result.confidence)), \(result.processingTimeMs)ms)")

            // Check for wake word and extract command
            if let commandText = commandProcessor.extractCommand(from: result.text) {
                lastCommand = commandText
                print("Wake word detected! Command: \"\(commandText)\"")

                // Process command with LLM
                await processCommand(commandText, speaker: speaker, source: source)
            } else {
                print("No wake word detected in: \"\(result.text)\"")
                // Return to listening state
                state = .listening
            }

        } catch {
            print("Processing error: \(error)")
            lastTranscription = "[Processing failed]"
            state = .listening
        }
    }

    private func processCommand(_ commandText: String, speaker: Speaker?, source: AudioSource) async {
        // Set state to responding
        state = .responding

        // Build command context
        let context = CommandContext(
            command: commandText,
            speaker: speaker,
            source: source,
            conversationHistory: conversationManager.getRecentHistory()
        )

        // Get conversation history for context
        let history = conversationManager.getRecentHistory()

        do {
            // Call LLM
            let response = try await llmService.complete(
                prompt: commandText,
                context: context,
                conversationHistory: history
            )

            // Update conversation history
            conversationManager.addTurn(role: .user, content: commandText)
            conversationManager.addTurn(role: .assistant, content: response)

            // Update UI with response
            lastResponse = response
            print("LLM Response: \(response)")

            // TODO: Milestone 5/6 - TTS/Audio response

        } catch let error as LLMError {
            print("LLM Error: \(error.localizedDescription)")
            lastResponse = "[Error: \(error.localizedDescription)]"
        } catch {
            print("Unexpected error: \(error)")
            lastResponse = "[Error processing command]"
        }

        // Return to listening state
        state = .listening
    }

    /// Clear conversation history (e.g., for "new conversation" command)
    func clearConversation() {
        conversationManager.clearHistory()
    }
}
```

**Step 2: Build to verify compilation**

In Xcode: Press `Cmd+B` to build.

Expected: Build succeeds with no errors

**Step 3: Commit**

```bash
git add HeyLlama/Core/AssistantCoordinator.swift
git commit -m "feat(core): integrate LLM into AssistantCoordinator with conversation context"
```

---

## Task 11: Update AppState for LLM Properties

**Files:**
- Modify: `HeyLlama/App/AppState.swift`

**Step 1: Update AppState to expose LLM properties**

Update `HeyLlama/App/AppState.swift`:

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
    @Published private(set) var lastResponse: String?
    @Published private(set) var isModelLoading: Bool = false
    @Published private(set) var currentSpeaker: Speaker?
    @Published private(set) var enrolledSpeakers: [Speaker] = []
    @Published private(set) var llmConfigured: Bool = false
    @Published var requiresOnboarding: Bool = true
    @Published var showOnboarding: Bool = false

    private var cancellables = Set<AnyCancellable>()

    init(coordinator: AssistantCoordinator? = nil) {
        self.coordinator = coordinator ?? AssistantCoordinator()
        self.requiresOnboarding = self.coordinator.requiresOnboarding
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

        coordinator.$lastResponse
            .receive(on: DispatchQueue.main)
            .assign(to: &$lastResponse)

        coordinator.$isModelLoading
            .receive(on: DispatchQueue.main)
            .assign(to: &$isModelLoading)

        coordinator.$currentSpeaker
            .receive(on: DispatchQueue.main)
            .assign(to: &$currentSpeaker)

        coordinator.$enrolledSpeakers
            .receive(on: DispatchQueue.main)
            .assign(to: &$enrolledSpeakers)

        coordinator.$requiresOnboarding
            .receive(on: DispatchQueue.main)
            .assign(to: &$requiresOnboarding)

        coordinator.$llmConfigured
            .receive(on: DispatchQueue.main)
            .assign(to: &$llmConfigured)
    }

    func checkAndShowOnboarding() {
        if coordinator.checkOnboardingRequired() {
            showOnboarding = true
        }
    }

    func completeOnboarding() {
        coordinator.completeOnboarding()
        showOnboarding = false
        requiresOnboarding = false
    }

    func start() async {
        guard !requiresOnboarding else {
            showOnboarding = true
            return
        }
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
git commit -m "feat(app): expose LLM response and configuration status in AppState"
```

---

## Task 12: Update MenuBarView with Response Display

**Files:**
- Modify: `HeyLlama/UI/MenuBar/MenuBarView.swift`

**Step 1: Update MenuBarView to show LLM responses**

Update `HeyLlama/UI/MenuBar/MenuBarView.swift`:

```swift
import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.openWindow) private var openWindow

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
                } else if appState.requiresOnboarding {
                    Text("Setup required")
                } else {
                    Text(appState.statusText)
                }
            }
            .foregroundColor(statusColor)

            // LLM configuration warning
            if !appState.requiresOnboarding && !appState.llmConfigured {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("AI not configured")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }

            if !appState.requiresOnboarding {
                AudioLevelIndicator(level: appState.audioLevel)
                    .frame(height: 4)
            }

            // Transcription section with speaker
            if let transcription = appState.lastTranscription, !transcription.isEmpty {
                Divider()

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("Last heard")
                        if let speaker = appState.currentSpeaker {
                            Text("(\(speaker.name)):")
                                .foregroundColor(.accentColor)
                        } else {
                            Text("(Guest):")
                                .foregroundColor(.secondary)
                        }
                    }
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

            // Response section
            if let response = appState.lastResponse, !response.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Response:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(response)
                        .font(.caption)
                        .foregroundColor(responseColor)
                        .lineLimit(4)
                }
            }

            Divider()

            // Actions
            if appState.requiresOnboarding {
                Button("Complete Setup...") {
                    openWindow(id: "onboarding")
                }
            } else {
                Button("Add Speaker...") {
                    openWindow(id: "enrollment")
                }
            }

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
        .frame(width: 260)
    }

    private var statusColor: Color {
        if appState.requiresOnboarding {
            return .orange
        }
        if appState.isModelLoading {
            return .orange
        }

        switch appState.statusText {
        case "Capturing...":
            return .green
        case "Processing...":
            return .orange
        case "Responding...":
            return .blue
        case _ where appState.statusText.hasPrefix("Error"):
            return .red
        default:
            return .secondary
        }
    }

    private var responseColor: Color {
        if let response = appState.lastResponse, response.hasPrefix("[Error") {
            return .red
        }
        return .primary
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
git commit -m "feat(ui): display LLM responses and configuration status in menu bar"
```

---

## Task 13: Update AssistantState for Responding State

**Files:**
- Modify: `HeyLlama/Core/AssistantState.swift`

**Step 1: Verify AssistantState has .responding case**

Check if `AssistantState` already includes `.responding`. If not, add it.

Expected content in `HeyLlama/Core/AssistantState.swift`:

```swift
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
        case .responding: return "text.bubble"
        case .error: return "exclamationmark.triangle"
        }
    }

    var statusText: String {
        switch self {
        case .idle: return "Idle"
        case .listening: return "Listening..."
        case .capturing: return "Capturing..."
        case .processing: return "Processing..."
        case .responding: return "Responding..."
        case .error(let msg): return "Error: \(msg)"
        }
    }
}
```

**Step 2: Build to verify compilation**

In Xcode: Press `Cmd+B` to build.

Expected: Build succeeds with no errors

**Step 3: Commit (if changes were needed)**

```bash
git add HeyLlama/Core/AssistantState.swift
git commit -m "feat(core): add responding state to AssistantState"
```

---

## Task 14: LLM Settings UI

**Files:**
- Create: `HeyLlama/UI/Settings/LLMSettingsView.swift`
- Modify: `HeyLlama/UI/Settings/SettingsView.swift`

**Step 1: Create LLMSettingsView**

Create `HeyLlama/UI/Settings/LLMSettingsView.swift`:

```swift
import SwiftUI

struct LLMSettingsView: View {
    @State private var config: AssistantConfig
    @State private var isSaving = false
    @State private var saveError: String?
    @State private var testResult: String?
    @State private var isTesting = false

    private let configStore: ConfigStore

    init() {
        let store = ConfigStore()
        self.configStore = store
        self._config = State(initialValue: store.loadConfig())
    }

    var body: some View {
        Form {
            // Provider Selection
            Section {
                Picker("AI Provider", selection: $config.llm.provider) {
                    Text("Apple Intelligence").tag(LLMProvider.appleIntelligence)
                    Text("OpenAI Compatible").tag(LLMProvider.openAICompatible)
                }
                .pickerStyle(.segmented)

                if config.llm.provider == .appleIntelligence {
                    appleIntelligenceSection
                } else {
                    openAICompatibleSection
                }
            }

            // System Prompt
            Section("System Prompt") {
                TextEditor(text: $config.llm.systemPrompt)
                    .font(.body.monospaced())
                    .frame(minHeight: 80)

                Text("Use {speaker_name} as a placeholder for the current speaker's name.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Button("Reset to Default") {
                    config.llm.systemPrompt = LLMConfig.defaultSystemPrompt
                }
                .buttonStyle(.link)
            }

            // Conversation Settings
            Section("Conversation") {
                Stepper(
                    "Context timeout: \(config.llm.conversationTimeoutMinutes) min",
                    value: $config.llm.conversationTimeoutMinutes,
                    in: 1...30
                )

                Stepper(
                    "Max history: \(config.llm.maxConversationTurns) turns",
                    value: $config.llm.maxConversationTurns,
                    in: 2...20
                )

                Text("Conversation history older than the timeout or beyond the max turns will not be sent to the AI.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Save/Test Section
            Section {
                HStack {
                    Button("Save") {
                        saveConfig()
                    }
                    .disabled(isSaving)

                    if isSaving {
                        ProgressView()
                            .scaleEffect(0.7)
                    }

                    Spacer()

                    Button("Test Connection") {
                        testConnection()
                    }
                    .disabled(isTesting || !isCurrentProviderConfigured)

                    if isTesting {
                        ProgressView()
                            .scaleEffect(0.7)
                    }
                }

                if let error = saveError {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }

                if let result = testResult {
                    Text(result)
                        .foregroundColor(result.contains("Success") ? .green : .red)
                        .font(.caption)
                }
            }
        }
        .padding()
    }

    private var appleIntelligenceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("Apple Intelligence is not yet available for third-party apps.")
                    .foregroundColor(.secondary)
            }
            .font(.caption)

            Text("Please select OpenAI Compatible and configure a local server like Ollama.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var openAICompatibleSection: some View {
        Group {
            TextField("Base URL", text: $config.llm.openAICompatible.baseURL)
                .textFieldStyle(.roundedBorder)

            TextField("Model", text: $config.llm.openAICompatible.model)
                .textFieldStyle(.roundedBorder)

            SecureField("API Key (optional)", text: Binding(
                get: { config.llm.openAICompatible.apiKey ?? "" },
                set: { config.llm.openAICompatible.apiKey = $0.isEmpty ? nil : $0 }
            ))
            .textFieldStyle(.roundedBorder)

            Stepper(
                "Timeout: \(config.llm.openAICompatible.timeoutSeconds)s",
                value: $config.llm.openAICompatible.timeoutSeconds,
                in: 10...300,
                step: 10
            )

            if !config.llm.openAICompatible.isConfigured {
                Text("Enter a base URL and model name to enable AI responses.")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
    }

    private var isCurrentProviderConfigured: Bool {
        switch config.llm.provider {
        case .appleIntelligence:
            return false // Not yet available
        case .openAICompatible:
            return config.llm.openAICompatible.isConfigured
        }
    }

    private func saveConfig() {
        isSaving = true
        saveError = nil

        do {
            try configStore.saveConfig(config)
            saveError = nil

            // Delay hiding the saving indicator
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isSaving = false
            }
        } catch {
            saveError = "Failed to save: \(error.localizedDescription)"
            isSaving = false
        }
    }

    private func testConnection() {
        isTesting = true
        testResult = nil

        Task {
            do {
                let provider = OpenAICompatibleProvider(
                    config: config.llm.openAICompatible,
                    systemPromptTemplate: config.llm.systemPrompt
                )

                let response = try await provider.complete(
                    prompt: "Say 'Connection successful!' in exactly 3 words.",
                    context: nil,
                    conversationHistory: []
                )

                await MainActor.run {
                    testResult = "Success: \(response)"
                    isTesting = false
                }
            } catch {
                await MainActor.run {
                    testResult = "Failed: \(error.localizedDescription)"
                    isTesting = false
                }
            }
        }
    }
}

#Preview {
    LLMSettingsView()
}
```

**Step 2: Update SettingsView to include LLM tab**

Update `HeyLlama/UI/Settings/SettingsView.swift`:

```swift
import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            LLMSettingsView()
                .tabItem {
                    Label("AI", systemImage: "brain")
                }

            AudioSettingsPlaceholder()
                .tabItem {
                    Label("Audio", systemImage: "waveform")
                }

            SpeakersSettingsView()
                .tabItem {
                    Label("Speakers", systemImage: "person.2")
                }

            Text("API settings coming in Milestone 6")
                .tabItem {
                    Label("API", systemImage: "network")
                }
        }
        .frame(width: 550, height: 400)
    }
}

struct GeneralSettingsView: View {
    var body: some View {
        Form {
            Section {
                Text("Wake phrase, launch at login, and other general settings will be added in Milestone 7.")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
}

struct AudioSettingsPlaceholder: View {
    var body: some View {
        Form {
            Section {
                Text("Audio device selection, silence threshold, and microphone testing will be added in Milestone 7.")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
}

#Preview {
    SettingsView()
}
```

**Step 3: Build to verify compilation**

In Xcode: Press `Cmd+B` to build.

Expected: Build succeeds with no errors

**Step 4: Commit**

```bash
git add HeyLlama/UI/Settings/LLMSettingsView.swift HeyLlama/UI/Settings/SettingsView.swift
git commit -m "feat(ui): add LLM settings view with provider configuration"
```

---

## Task 15: Integration Tests for LLM Flow

**Files:**
- Create: `HeyLlamaTests/AssistantCoordinatorLLMTests.swift`

**Step 1: Write integration tests**

Create `HeyLlamaTests/AssistantCoordinatorLLMTests.swift`:

```swift
import XCTest
@testable import HeyLlama

@MainActor
final class AssistantCoordinatorLLMTests: XCTestCase {

    func testConversationManagerIntegration() {
        let manager = ConversationManager(timeoutMinutes: 5, maxTurns: 10)

        // Simulate conversation
        manager.addTurn(role: .user, content: "What's the capital of France?")
        manager.addTurn(role: .assistant, content: "Paris")
        manager.addTurn(role: .user, content: "What language do they speak?")

        let history = manager.getRecentHistory()
        XCTAssertEqual(history.count, 3)
    }

    func testMockLLMServiceIntegration() async throws {
        let mockLLM = MockLLMService()
        await mockLLM.setMockResponse("It's 3:30 PM")

        let history = [
            ConversationTurn(role: .user, content: "Hello"),
            ConversationTurn(role: .assistant, content: "Hi!")
        ]

        let response = try await mockLLM.complete(
            prompt: "What time is it?",
            context: nil,
            conversationHistory: history
        )

        XCTAssertEqual(response, "It's 3:30 PM")

        let lastHistory = await mockLLM.lastConversationHistory
        XCTAssertEqual(lastHistory.count, 2)
    }

    func testOpenAIProviderRequestBodyStructure() {
        var config = OpenAICompatibleConfig()
        config.model = "llama3.2"

        let provider = OpenAICompatibleProvider(config: config)

        let history = [
            ConversationTurn(role: .user, content: "Hello"),
            ConversationTurn(role: .assistant, content: "Hi there!")
        ]

        let body = provider.buildRequestBody(
            systemPrompt: "Be helpful.",
            prompt: "How are you?",
            conversationHistory: history
        )

        let messages = body["messages"] as? [[String: String]]
        XCTAssertNotNil(messages)

        // Should have: system + history (2) + current prompt = 4 messages
        XCTAssertEqual(messages?.count, 4)

        // Verify message order
        XCTAssertEqual(messages?[0]["role"], "system")
        XCTAssertEqual(messages?[1]["role"], "user")
        XCTAssertEqual(messages?[1]["content"], "Hello")
        XCTAssertEqual(messages?[2]["role"], "assistant")
        XCTAssertEqual(messages?[2]["content"], "Hi there!")
        XCTAssertEqual(messages?[3]["role"], "user")
        XCTAssertEqual(messages?[3]["content"], "How are you?")
    }

    func testLLMConfigPersistence() throws {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

        defer {
            try? FileManager.default.removeItem(at: tempDirectory)
        }

        let store = ConfigStore(baseDirectory: tempDirectory)

        var config = AssistantConfig.default
        config.llm.provider = .openAICompatible
        config.llm.openAICompatible.model = "llama3.2"
        config.llm.openAICompatible.baseURL = "http://localhost:11434/v1"
        config.llm.conversationTimeoutMinutes = 10

        try store.saveConfig(config)
        let loaded = store.loadConfig()

        XCTAssertEqual(loaded.llm.provider, .openAICompatible)
        XCTAssertEqual(loaded.llm.openAICompatible.model, "llama3.2")
        XCTAssertEqual(loaded.llm.conversationTimeoutMinutes, 10)
    }
}
```

**Step 2: Run tests**

In Xcode: Run `AssistantCoordinatorLLMTests` via Test Navigator (`Cmd+6`) or press `Cmd+U` for all tests.

Expected: All tests pass (green checkmarks)

**Step 3: Commit**

```bash
git add HeyLlamaTests/AssistantCoordinatorLLMTests.swift
git commit -m "test(coordinator): add integration tests for LLM flow"
```

---

## Task 16: Run Full Test Suite

**Step 1: Clean and run all tests**

In Xcode:
1. Press `Cmd+Shift+K` to clean build folder
2. Press `Cmd+U` to run all tests

Expected: All tests pass (green checkmarks in Test Navigator)

**Step 2: Fix any failing tests**

If tests fail, debug and fix issues. Report failures to Claude for assistance.

---

## Task 17: Manual Integration Testing

**Step 1: Configure Ollama (or similar local LLM)**

If you have Ollama installed:

```bash
# Start Ollama server
ollama serve

# Pull a model (if not already done)
ollama pull llama3.2
```

**Step 2: Run the app**

In Xcode: Press `Cmd+R` to build and run the app.

**Step 3: Configure LLM in Settings**

1. Click menu bar icon → Preferences
2. Go to "AI" tab
3. Select "OpenAI Compatible"
4. Enter:
   - Base URL: `http://localhost:11434/v1`
   - Model: `llama3.2`
5. Click "Save"
6. Click "Test Connection" to verify

**Step 4: Manual testing checklist**

Test the running app:

- [ ] App shows warning if AI not configured
- [ ] Settings show LLM configuration options
- [ ] Can save LLM configuration
- [ ] Test connection works with local Ollama
- [ ] Say "Hey Llama, what time is it?"
  - Command appears in menu bar
  - "Responding..." state is shown
  - Response appears in menu bar
- [ ] Say "Hey Llama, what's the capital of France?"
  - Response: "Paris" (or similar)
- [ ] Follow up with "What language do they speak there?"
  - Response should acknowledge France context
- [ ] Wait 6+ minutes (or configure shorter timeout)
- [ ] Ask unrelated question: "Hey Llama, what's 2+2?"
  - Should work without old context
- [ ] Test error handling:
  - Stop Ollama server
  - Say a command
  - Error message should appear in menu bar

**Step 5: Stop the app**

In Xcode: Press `Cmd+.` to stop the running app.

---

## Task 18: Final Milestone Commit

**Step 1: Create milestone commit**

```bash
git add .
git commit -m "$(cat <<'EOF'
Milestone 4: LLM integration with multi-turn conversation support

- Add LLM provider abstraction (Apple Intelligence stub + OpenAI-compatible)
- Implement OpenAICompatibleProvider with full API support
- Add ConversationManager for time-based conversation context
- Create AssistantConfig and ConfigStore for settings persistence
- Add LLMConfig with provider selection and conversation settings
- Integrate LLM into AssistantCoordinator pipeline
- Add LLM settings UI with provider configuration and testing
- Display LLM responses in menu bar dropdown
- Add comprehensive unit and integration tests
- Support multi-turn conversations with configurable timeout/history

EOF
)"
```

---

## Summary

This plan implements Milestone 4 in 18 tasks:

1. **LLMConfig** - Provider and configuration models
2. **AssistantConfig** - Main app configuration with LLM settings
3. **ConfigStore** - JSON persistence for configuration
4. **ConversationManager** - Multi-turn context with time windowing
5. **LLMServiceProtocol** - Service protocol and error types
6. **MockLLMService** - Mock for testing
7. **OpenAICompatibleProvider** - Full OpenAI API implementation
8. **AppleIntelligenceProvider** - Stub for future Apple API
9. **LLMService** - Facade delegating to providers
10. **AssistantCoordinator** - LLM integration
11. **AppState** - Expose LLM properties
12. **MenuBarView** - Display responses
13. **AssistantState** - Add .responding state
14. **LLMSettingsView** - Settings UI
15. **Integration Tests** - LLM flow tests
16. **Full Test Suite** - Run all tests
17. **Manual Testing** - Integration verification
18. **Final Commit** - Milestone commit

**Deliverable:** LLM-backed assistant that responds to voice commands with text responses displayed in the menu bar. Supports multi-turn conversations with time-based context windowing. Configurable via settings for Apple Intelligence (stub) or OpenAI-compatible providers (Ollama, LM Studio, etc.).

---

## Multi-Turn Conversation Design Notes

### How It Works

1. User says "Hey Llama, what's the capital of France?"
2. LLM responds "Paris"
3. Both turns are stored with timestamps
4. User says "What language do they speak there?" (within 5 minutes)
5. ConversationManager includes both previous turns in the request
6. LLM sees context and responds about French

### Time Window Behavior

- Turns older than `conversationTimeoutMinutes` are pruned
- Maximum of `maxConversationTurns` are kept
- Pruning happens on each request
- This ensures fresh starts for unrelated topics

### Future Enhancements (Not in Milestone 4)

1. **Per-Speaker Histories**: Track conversations per enrolled speaker
2. **Explicit Reset**: "Hey Llama, new conversation" command
3. **Topic Detection**: Use embeddings to detect topic changes
4. **Conversation Summary**: Summarize long histories to save tokens
