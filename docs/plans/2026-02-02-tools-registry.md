# Tools/Skills Registry Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Create a registerable tools/skills system that allows the LLM to trigger real actions (weather lookup, add reminders) via structured JSON responses.

**Architecture:** The SkillsRegistry holds all available skills via a `RegisteredSkill` enum (we avoided protocol existentials due to memory issues). When the user speaks a command, the LLM receives a skills manifest in its prompt and returns structured JSON indicating either a text response or a skill call. The coordinator parses this JSON, validates the skill is enabled, executes it, and returns the result to the user.

**Tech Stack:** Swift 5.9+, Foundation Models (tool calling for Apple Intelligence), OpenAI-compatible JSON function calling, WeatherKit, EventKit (Reminders)

---

## Implementation Notes (Updated During Development)

**Architectural changes from original plan:**
1. **No `Skill` protocol** - Protocol existentials (`any Skill`) caused memory corruption during tests. We use a `RegisteredSkill` enum instead that holds all skill metadata and dispatches to concrete skill structs.
2. **`SkillsRegistry` is a `struct`** - Using a `class` also caused memory corruption. The struct stores `enabledSkillIds` directly.
3. **Test file renamed** - `SkillsRegistryTests.swift` → `ToolsRegistryTests.swift`
4. **Skill implementations** - `WeatherForecastSkill` and `RemindersAddItemSkill` are plain structs (no protocol conformance) called by `RegisteredSkill.run()`.

---

## Overview

This plan implements Milestone 5 from `docs/milestones/05-tools-registry.md`. The existing LLM integration (Milestone 4) returns plain text responses. This milestone adds:

1. A **RegisteredSkill** enum and **SkillsRegistry** struct for registering/managing skills
2. **Structured JSON output** from LLMs (action plans) instead of plain text
3. Two starter skills: **Weather Forecast** and **Add Reminder**
4. **Permission management** for skills requiring system access
5. **Settings UI** for enabling/disabling skills

Key files we'll modify:
- `HeyLlama/Services/LLM/` - Add structured output support to providers
- `HeyLlama/Core/AssistantCoordinator.swift` - Process action plans
- `HeyLlama/Storage/AssistantConfig.swift` - Add skills config ✅ DONE

Key files we'll create:
- `HeyLlama/Services/Skills/` - Skill types, registry, and implementations ✅ DONE (Tasks 1-3)
- `HeyLlama/Models/LLMActionPlan.swift` - JSON response model ✅ DONE
- `HeyLlama/UI/Settings/SkillsSettingsView.swift` - Skills management UI

---

## Task 1: Define Skill Protocol and Permission Types

**Files:**
- Create: `HeyLlama/Services/Skills/SkillProtocol.swift`
- Create: `HeyLlama/Services/Skills/SkillPermission.swift`
- Test: `HeyLlamaTests/SkillProtocolTests.swift`

### Step 1: Write the failing test for Skill protocol

```swift
// HeyLlamaTests/SkillProtocolTests.swift
import XCTest
@testable import HeyLlama

final class SkillProtocolTests: XCTestCase {

    func testSkillHasRequiredProperties() {
        // Test that a mock skill conforms to protocol with all required properties
        let skill = MockTestSkill()

        XCTAssertEqual(skill.id, "test.mock_skill")
        XCTAssertEqual(skill.name, "Mock Skill")
        XCTAssertFalse(skill.description.isEmpty)
        XCTAssertEqual(skill.requiredPermissions, [])
        XCTAssertFalse(skill.argumentSchemaJSON.isEmpty)
    }

    func testSkillResultContainsText() {
        let result = SkillResult(text: "Operation completed", data: nil)

        XCTAssertEqual(result.text, "Operation completed")
        XCTAssertNil(result.data)
    }

    func testSkillResultWithData() {
        let data: [String: Any] = ["temperature": 72, "unit": "F"]
        let result = SkillResult(text: "Current temperature", data: data)

        XCTAssertEqual(result.text, "Current temperature")
        XCTAssertNotNil(result.data)
        XCTAssertEqual(result.data?["temperature"] as? Int, 72)
    }
}

// Mock skill for testing
struct MockTestSkill: Skill {
    var id: String { "test.mock_skill" }
    var name: String { "Mock Skill" }
    var description: String { "A mock skill for testing" }
    var requiredPermissions: [SkillPermission] { [] }
    var argumentSchemaJSON: String {
        """
        {"type":"object","properties":{"value":{"type":"string"}}}
        """
    }

    func run(argumentsJSON: String, context: SkillContext) async throws -> SkillResult {
        return SkillResult(text: "Mock result", data: nil)
    }
}
```

### Step 2: Run test to verify it fails

Run: Open Xcode, `Cmd+U` or navigate to Test Navigator (`Cmd+6`) and run `SkillProtocolTests`
Expected: FAIL with "Cannot find type 'Skill' in scope" and similar errors

### Step 3: Write the Skill protocol and SkillPermission

```swift
// HeyLlama/Services/Skills/SkillPermission.swift
import Foundation

/// Permissions that skills may require
enum SkillPermission: String, Codable, CaseIterable, Sendable {
    case reminders = "reminders"
    case location = "location"

    var displayName: String {
        switch self {
        case .reminders:
            return "Reminders"
        case .location:
            return "Location"
        }
    }

    var description: String {
        switch self {
        case .reminders:
            return "Access to create and manage reminders"
        case .location:
            return "Access to your location for weather forecasts"
        }
    }

    var systemSettingsKey: String {
        switch self {
        case .reminders:
            return "Privacy_Reminders"
        case .location:
            return "Privacy_LocationServices"
        }
    }
}
```

```swift
// HeyLlama/Services/Skills/SkillProtocol.swift
import Foundation

/// Context passed to skills when they execute
struct SkillContext: Sendable {
    let speaker: Speaker?
    let source: AudioSource
    let timestamp: Date

    init(speaker: Speaker? = nil, source: AudioSource = .localMic, timestamp: Date = Date()) {
        self.speaker = speaker
        self.source = source
        self.timestamp = timestamp
    }
}

/// Result returned by a skill after execution
struct SkillResult: Sendable {
    let text: String
    let data: [String: Any]?

    init(text: String, data: [String: Any]? = nil) {
        self.text = text
        self.data = data
    }
}

/// Errors that can occur during skill execution
enum SkillError: Error, LocalizedError, Equatable {
    case permissionDenied(SkillPermission)
    case permissionNotRequested(SkillPermission)
    case invalidArguments(String)
    case executionFailed(String)
    case skillNotFound(String)
    case skillDisabled(String)

    var errorDescription: String? {
        switch self {
        case .permissionDenied(let permission):
            return "\(permission.displayName) permission was denied"
        case .permissionNotRequested(let permission):
            return "\(permission.displayName) permission has not been requested"
        case .invalidArguments(let message):
            return "Invalid arguments: \(message)"
        case .executionFailed(let message):
            return "Skill execution failed: \(message)"
        case .skillNotFound(let id):
            return "Skill not found: \(id)"
        case .skillDisabled(let id):
            return "Skill is disabled: \(id)"
        }
    }
}

/// Protocol that all skills must conform to
protocol Skill: Sendable {
    /// Unique identifier for the skill (e.g., "weather.forecast", "reminders.add_item")
    var id: String { get }

    /// Human-readable name for display in UI
    var name: String { get }

    /// Description of what the skill does (shown in UI and injected into LLM prompt)
    var description: String { get }

    /// Permissions required by this skill
    var requiredPermissions: [SkillPermission] { get }

    /// JSON Schema describing the arguments this skill accepts
    /// This is injected into the LLM prompt so it knows what arguments to provide
    var argumentSchemaJSON: String { get }

    /// Execute the skill with the provided arguments
    /// - Parameters:
    ///   - argumentsJSON: JSON string containing the arguments
    ///   - context: Context about the command (speaker, source, etc.)
    /// - Returns: Result containing response text and optional structured data
    func run(argumentsJSON: String, context: SkillContext) async throws -> SkillResult
}
```

### Step 4: Run test to verify it passes

Run: `Cmd+U` or run `SkillProtocolTests` from Test Navigator
Expected: PASS

### Step 5: Commit

```bash
git add HeyLlama/Services/Skills/SkillProtocol.swift HeyLlama/Services/Skills/SkillPermission.swift HeyLlamaTests/SkillProtocolTests.swift
git commit -m "feat(skills): add Skill protocol and SkillPermission types"
```

---

## Task 2: Define LLM Action Plan Model

**Files:**
- Create: `HeyLlama/Models/LLMActionPlan.swift`
- Test: `HeyLlamaTests/LLMActionPlanTests.swift`

### Step 1: Write the failing test for LLMActionPlan

```swift
// HeyLlamaTests/LLMActionPlanTests.swift
import XCTest
@testable import HeyLlama

final class LLMActionPlanTests: XCTestCase {

    // MARK: - Respond Action Tests

    func testDecodeRespondAction() throws {
        let json = """
        {"type":"respond","text":"The weather looks great today!"}
        """

        let plan = try LLMActionPlan.parse(from: json)

        guard case .respond(let text) = plan else {
            XCTFail("Expected respond action")
            return
        }

        XCTAssertEqual(text, "The weather looks great today!")
    }

    func testDecodeRespondActionWithQuotes() throws {
        let json = """
        {"type":"respond","text":"She said \\"hello\\" to me"}
        """

        let plan = try LLMActionPlan.parse(from: json)

        guard case .respond(let text) = plan else {
            XCTFail("Expected respond action")
            return
        }

        XCTAssertEqual(text, "She said \"hello\" to me")
    }

    // MARK: - Call Skills Action Tests

    func testDecodeCallSkillsAction() throws {
        let json = """
        {"type":"call_skills","calls":[{"skillId":"weather.forecast","arguments":{"when":"today"}}]}
        """

        let plan = try LLMActionPlan.parse(from: json)

        guard case .callSkills(let calls) = plan else {
            XCTFail("Expected call_skills action")
            return
        }

        XCTAssertEqual(calls.count, 1)
        XCTAssertEqual(calls[0].skillId, "weather.forecast")
        XCTAssertEqual(calls[0].arguments["when"] as? String, "today")
    }

    func testDecodeMultipleSkillCalls() throws {
        let json = """
        {"type":"call_skills","calls":[
            {"skillId":"weather.forecast","arguments":{"when":"today"}},
            {"skillId":"reminders.add_item","arguments":{"listName":"Groceries","itemName":"Milk"}}
        ]}
        """

        let plan = try LLMActionPlan.parse(from: json)

        guard case .callSkills(let calls) = plan else {
            XCTFail("Expected call_skills action")
            return
        }

        XCTAssertEqual(calls.count, 2)
        XCTAssertEqual(calls[0].skillId, "weather.forecast")
        XCTAssertEqual(calls[1].skillId, "reminders.add_item")
        XCTAssertEqual(calls[1].arguments["listName"] as? String, "Groceries")
    }

    // MARK: - Error Handling Tests

    func testDecodeInvalidJSON() {
        let json = "not valid json"

        XCTAssertThrowsError(try LLMActionPlan.parse(from: json)) { error in
            guard case LLMActionPlanError.invalidJSON = error else {
                XCTFail("Expected invalidJSON error, got: \(error)")
                return
            }
        }
    }

    func testDecodeMissingType() {
        let json = """
        {"text":"Hello"}
        """

        XCTAssertThrowsError(try LLMActionPlan.parse(from: json)) { error in
            guard case LLMActionPlanError.missingType = error else {
                XCTFail("Expected missingType error, got: \(error)")
                return
            }
        }
    }

    func testDecodeUnknownType() {
        let json = """
        {"type":"unknown_action","data":{}}
        """

        XCTAssertThrowsError(try LLMActionPlan.parse(from: json)) { error in
            guard case LLMActionPlanError.unknownType(let type) = error else {
                XCTFail("Expected unknownType error, got: \(error)")
                return
            }
            XCTAssertEqual(type, "unknown_action")
        }
    }

    func testDecodeMissingTextForRespond() {
        let json = """
        {"type":"respond"}
        """

        XCTAssertThrowsError(try LLMActionPlan.parse(from: json)) { error in
            guard case LLMActionPlanError.missingField(let field) = error else {
                XCTFail("Expected missingField error, got: \(error)")
                return
            }
            XCTAssertEqual(field, "text")
        }
    }

    func testDecodeMissingCallsForCallSkills() {
        let json = """
        {"type":"call_skills"}
        """

        XCTAssertThrowsError(try LLMActionPlan.parse(from: json)) { error in
            guard case LLMActionPlanError.missingField(let field) = error else {
                XCTFail("Expected missingField error, got: \(error)")
                return
            }
            XCTAssertEqual(field, "calls")
        }
    }

    // MARK: - SkillCall Tests

    func testSkillCallArgumentsJSON() throws {
        let json = """
        {"type":"call_skills","calls":[{"skillId":"test","arguments":{"name":"value","count":42}}]}
        """

        let plan = try LLMActionPlan.parse(from: json)

        guard case .callSkills(let calls) = plan else {
            XCTFail("Expected call_skills action")
            return
        }

        let argsJSON = try calls[0].argumentsAsJSON()
        XCTAssertTrue(argsJSON.contains("\"name\""))
        XCTAssertTrue(argsJSON.contains("\"value\""))
        XCTAssertTrue(argsJSON.contains("42"))
    }

    // MARK: - Whitespace and Formatting Tests

    func testDecodeWithExtraWhitespace() throws {
        let json = """
          {
            "type" : "respond" ,
            "text" : "Hello world"
          }
        """

        let plan = try LLMActionPlan.parse(from: json)

        guard case .respond(let text) = plan else {
            XCTFail("Expected respond action")
            return
        }

        XCTAssertEqual(text, "Hello world")
    }
}
```

### Step 2: Run test to verify it fails

Run: `Cmd+U` or run `LLMActionPlanTests` from Test Navigator
Expected: FAIL with "Cannot find type 'LLMActionPlan' in scope"

### Step 3: Write the LLMActionPlan model

```swift
// HeyLlama/Models/LLMActionPlan.swift
import Foundation

/// Errors that can occur when parsing LLM action plans
enum LLMActionPlanError: Error, LocalizedError, Equatable {
    case invalidJSON
    case missingType
    case unknownType(String)
    case missingField(String)
    case invalidField(String, String)

    var errorDescription: String? {
        switch self {
        case .invalidJSON:
            return "Invalid JSON response from LLM"
        case .missingType:
            return "Missing 'type' field in action plan"
        case .unknownType(let type):
            return "Unknown action type: \(type)"
        case .missingField(let field):
            return "Missing required field: \(field)"
        case .invalidField(let field, let reason):
            return "Invalid field '\(field)': \(reason)"
        }
    }
}

/// A skill call requested by the LLM
struct SkillCall: Sendable {
    let skillId: String
    let arguments: [String: Any]

    /// Convert arguments back to JSON string for passing to skill
    func argumentsAsJSON() throws -> String {
        let data = try JSONSerialization.data(withJSONObject: arguments, options: [])
        guard let string = String(data: data, encoding: .utf8) else {
            throw LLMActionPlanError.invalidJSON
        }
        return string
    }
}

/// The action plan returned by the LLM
enum LLMActionPlan: Sendable {
    /// LLM wants to respond with text directly
    case respond(text: String)

    /// LLM wants to call one or more skills
    case callSkills(calls: [SkillCall])

    /// Parse an action plan from JSON string
    static func parse(from jsonString: String) throws -> LLMActionPlan {
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw LLMActionPlanError.invalidJSON
        }

        guard let type = json["type"] as? String else {
            throw LLMActionPlanError.missingType
        }

        switch type {
        case "respond":
            guard let text = json["text"] as? String else {
                throw LLMActionPlanError.missingField("text")
            }
            return .respond(text: text)

        case "call_skills":
            guard let callsArray = json["calls"] as? [[String: Any]] else {
                throw LLMActionPlanError.missingField("calls")
            }

            let calls = try callsArray.map { callDict -> SkillCall in
                guard let skillId = callDict["skillId"] as? String else {
                    throw LLMActionPlanError.missingField("skillId")
                }
                let arguments = callDict["arguments"] as? [String: Any] ?? [:]
                return SkillCall(skillId: skillId, arguments: arguments)
            }

            return .callSkills(calls: calls)

        default:
            throw LLMActionPlanError.unknownType(type)
        }
    }
}
```

### Step 4: Run test to verify it passes

Run: `Cmd+U` or run `LLMActionPlanTests` from Test Navigator
Expected: PASS

### Step 5: Commit

```bash
git add HeyLlama/Models/LLMActionPlan.swift HeyLlamaTests/LLMActionPlanTests.swift
git commit -m "feat(skills): add LLMActionPlan model for structured LLM output"
```

---

## Task 3: Create Skills Registry

**Files:**
- Create: `HeyLlama/Services/Skills/SkillsRegistry.swift`
- Create: `HeyLlama/Storage/SkillsConfig.swift`
- Modify: `HeyLlama/Storage/AssistantConfig.swift`
- Test: `HeyLlamaTests/SkillsRegistryTests.swift`

### Step 1: Write the failing test for SkillsRegistry

```swift
// HeyLlamaTests/SkillsRegistryTests.swift
import XCTest
@testable import HeyLlama

final class SkillsRegistryTests: XCTestCase {

    // MARK: - Registration Tests

    func testRegistryHasBuiltInSkills() {
        let registry = SkillsRegistry()
        let allSkills = registry.allSkills

        // Should have weather and reminders skills
        XCTAssertGreaterThanOrEqual(allSkills.count, 2)
        XCTAssertTrue(allSkills.contains { $0.id == "weather.forecast" })
        XCTAssertTrue(allSkills.contains { $0.id == "reminders.add_item" })
    }

    func testGetSkillById() {
        let registry = SkillsRegistry()

        let skill = registry.skill(withId: "weather.forecast")
        XCTAssertNotNil(skill)
        XCTAssertEqual(skill?.id, "weather.forecast")
    }

    func testGetNonexistentSkill() {
        let registry = SkillsRegistry()

        let skill = registry.skill(withId: "nonexistent.skill")
        XCTAssertNil(skill)
    }

    // MARK: - Enable/Disable Tests

    func testSkillsDisabledByDefault() {
        let config = SkillsConfig()
        let registry = SkillsRegistry(config: config)

        let enabledSkills = registry.enabledSkills
        XCTAssertTrue(enabledSkills.isEmpty, "Skills should be disabled by default")
    }

    func testEnableSkill() {
        var config = SkillsConfig()
        config.enabledSkillIds = ["weather.forecast"]
        let registry = SkillsRegistry(config: config)

        let enabledSkills = registry.enabledSkills
        XCTAssertEqual(enabledSkills.count, 1)
        XCTAssertEqual(enabledSkills.first?.id, "weather.forecast")
    }

    func testEnableMultipleSkills() {
        var config = SkillsConfig()
        config.enabledSkillIds = ["weather.forecast", "reminders.add_item"]
        let registry = SkillsRegistry(config: config)

        let enabledSkills = registry.enabledSkills
        XCTAssertEqual(enabledSkills.count, 2)
    }

    func testEnableNonexistentSkillIgnored() {
        var config = SkillsConfig()
        config.enabledSkillIds = ["weather.forecast", "nonexistent.skill"]
        let registry = SkillsRegistry(config: config)

        let enabledSkills = registry.enabledSkills
        XCTAssertEqual(enabledSkills.count, 1)
        XCTAssertEqual(enabledSkills.first?.id, "weather.forecast")
    }

    func testIsSkillEnabled() {
        var config = SkillsConfig()
        config.enabledSkillIds = ["weather.forecast"]
        let registry = SkillsRegistry(config: config)

        XCTAssertTrue(registry.isSkillEnabled("weather.forecast"))
        XCTAssertFalse(registry.isSkillEnabled("reminders.add_item"))
    }

    // MARK: - Manifest Generation Tests

    func testGenerateManifestForEnabledSkills() {
        var config = SkillsConfig()
        config.enabledSkillIds = ["weather.forecast"]
        let registry = SkillsRegistry(config: config)

        let manifest = registry.generateSkillsManifest()

        XCTAssertTrue(manifest.contains("weather.forecast"))
        XCTAssertTrue(manifest.contains("Weather Forecast"))
        XCTAssertFalse(manifest.contains("reminders.add_item"))
    }

    func testManifestIsEmptyWhenNoSkillsEnabled() {
        let config = SkillsConfig()
        let registry = SkillsRegistry(config: config)

        let manifest = registry.generateSkillsManifest()

        XCTAssertTrue(manifest.contains("No skills are currently enabled"))
    }

    func testManifestIncludesArgumentSchema() {
        var config = SkillsConfig()
        config.enabledSkillIds = ["weather.forecast"]
        let registry = SkillsRegistry(config: config)

        let manifest = registry.generateSkillsManifest()

        // Should include the JSON schema for arguments
        XCTAssertTrue(manifest.contains("arguments"))
    }

    // MARK: - Config Update Tests

    func testUpdateConfig() {
        let registry = SkillsRegistry()

        XCTAssertTrue(registry.enabledSkills.isEmpty)

        var newConfig = SkillsConfig()
        newConfig.enabledSkillIds = ["weather.forecast"]
        registry.updateConfig(newConfig)

        XCTAssertEqual(registry.enabledSkills.count, 1)
    }
}
```

### Step 2: Run test to verify it fails

Run: `Cmd+U` or run `SkillsRegistryTests` from Test Navigator
Expected: FAIL with "Cannot find type 'SkillsRegistry' in scope"

### Step 3: Write SkillsConfig

```swift
// HeyLlama/Storage/SkillsConfig.swift
import Foundation

/// Configuration for the skills system
struct SkillsConfig: Codable, Equatable, Sendable {
    /// IDs of skills that are enabled
    var enabledSkillIds: [String]

    init(enabledSkillIds: [String] = []) {
        self.enabledSkillIds = enabledSkillIds
    }

    /// Check if a specific skill is enabled
    func isSkillEnabled(_ skillId: String) -> Bool {
        enabledSkillIds.contains(skillId)
    }
}
```

### Step 4: Modify AssistantConfig to include SkillsConfig

```swift
// In HeyLlama/Storage/AssistantConfig.swift
// Add skills property to the struct:

/// Main configuration for the assistant
struct AssistantConfig: Equatable, Sendable {
    var wakePhrase: String
    var wakeWordSensitivity: Float
    var apiPort: UInt16
    var apiEnabled: Bool
    var llm: LLMConfig
    var skills: SkillsConfig  // ADD THIS LINE

    nonisolated init(
        wakePhrase: String = "hey llama",
        wakeWordSensitivity: Float = 0.5,
        apiPort: UInt16 = 8765,
        apiEnabled: Bool = true,
        llm: LLMConfig = .default,
        skills: SkillsConfig = SkillsConfig()  // ADD THIS PARAMETER
    ) {
        self.wakePhrase = wakePhrase
        self.wakeWordSensitivity = wakeWordSensitivity
        self.apiPort = apiPort
        self.apiEnabled = apiEnabled
        self.llm = llm
        self.skills = skills  // ADD THIS LINE
    }

    // ... rest stays the same, but update CodingKeys and Codable conformance
}

// Update the Codable extension:
extension AssistantConfig: Codable {
    private enum CodingKeys: String, CodingKey {
        case wakePhrase, wakeWordSensitivity, apiPort, apiEnabled, llm, skills  // ADD skills
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        wakePhrase = try container.decode(String.self, forKey: .wakePhrase)
        wakeWordSensitivity = try container.decode(Float.self, forKey: .wakeWordSensitivity)
        apiPort = try container.decode(UInt16.self, forKey: .apiPort)
        apiEnabled = try container.decode(Bool.self, forKey: .apiEnabled)
        llm = try container.decode(LLMConfig.self, forKey: .llm)
        skills = try container.decodeIfPresent(SkillsConfig.self, forKey: .skills) ?? SkillsConfig()  // ADD THIS
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(wakePhrase, forKey: .wakePhrase)
        try container.encode(wakeWordSensitivity, forKey: .wakeWordSensitivity)
        try container.encode(apiPort, forKey: .apiPort)
        try container.encode(apiEnabled, forKey: .apiEnabled)
        try container.encode(llm, forKey: .llm)
        try container.encode(skills, forKey: .skills)  // ADD THIS
    }
}
```

### Step 5: Write placeholder skills for registry (we'll implement them fully later)

```swift
// HeyLlama/Services/Skills/WeatherForecastSkill.swift
import Foundation

/// Weather forecast skill using WeatherKit
struct WeatherForecastSkill: Skill {
    var id: String { "weather.forecast" }
    var name: String { "Weather Forecast" }
    var description: String { "Get the weather forecast for today, tomorrow, or the next 7 days" }
    var requiredPermissions: [SkillPermission] { [.location] }

    var argumentSchemaJSON: String {
        """
        {
            "type": "object",
            "properties": {
                "when": {
                    "type": "string",
                    "enum": ["today", "tomorrow", "next_7_days"],
                    "description": "The time period for the forecast"
                },
                "location": {
                    "type": "string",
                    "description": "Optional location name. If omitted, uses current location."
                }
            },
            "required": ["when"]
        }
        """
    }

    func run(argumentsJSON: String, context: SkillContext) async throws -> SkillResult {
        // Placeholder - will implement in Task 6
        return SkillResult(text: "Weather skill not yet implemented", data: nil)
    }
}
```

```swift
// HeyLlama/Services/Skills/RemindersAddItemSkill.swift
import Foundation

/// Skill to add items to Reminders lists
struct RemindersAddItemSkill: Skill {
    var id: String { "reminders.add_item" }
    var name: String { "Add Reminder" }
    var description: String { "Add an item to a Reminders list (e.g., 'add milk to the groceries list')" }
    var requiredPermissions: [SkillPermission] { [.reminders] }

    var argumentSchemaJSON: String {
        """
        {
            "type": "object",
            "properties": {
                "listName": {
                    "type": "string",
                    "description": "The name of the Reminders list to add to"
                },
                "itemName": {
                    "type": "string",
                    "description": "The item/reminder to add"
                },
                "notes": {
                    "type": "string",
                    "description": "Optional notes for the reminder"
                },
                "dueDateISO8601": {
                    "type": "string",
                    "description": "Optional due date in ISO8601 format"
                }
            },
            "required": ["listName", "itemName"]
        }
        """
    }

    func run(argumentsJSON: String, context: SkillContext) async throws -> SkillResult {
        // Placeholder - will implement in Task 7
        return SkillResult(text: "Reminders skill not yet implemented", data: nil)
    }
}
```

### Step 6: Write SkillsRegistry

```swift
// HeyLlama/Services/Skills/SkillsRegistry.swift
import Foundation

/// Central registry for all available skills
final class SkillsRegistry: @unchecked Sendable {
    private var config: SkillsConfig
    private let registeredSkills: [any Skill]
    private let lock = NSLock()

    /// All skills registered in the system
    var allSkills: [any Skill] {
        registeredSkills
    }

    /// Skills that are currently enabled based on config
    var enabledSkills: [any Skill] {
        lock.lock()
        defer { lock.unlock() }
        return registeredSkills.filter { config.enabledSkillIds.contains($0.id) }
    }

    init(config: SkillsConfig = SkillsConfig()) {
        self.config = config

        // Register all built-in skills
        self.registeredSkills = [
            WeatherForecastSkill(),
            RemindersAddItemSkill()
        ]
    }

    /// Get a skill by its ID
    func skill(withId id: String) -> (any Skill)? {
        registeredSkills.first { $0.id == id }
    }

    /// Check if a skill is enabled
    func isSkillEnabled(_ skillId: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return config.enabledSkillIds.contains(skillId)
    }

    /// Update the skills configuration
    func updateConfig(_ newConfig: SkillsConfig) {
        lock.lock()
        defer { lock.unlock() }
        config = newConfig
    }

    /// Generate a manifest of enabled skills for LLM prompt injection
    func generateSkillsManifest() -> String {
        let enabled = enabledSkills

        guard !enabled.isEmpty else {
            return "No skills are currently enabled. Respond with a helpful text message."
        }

        var manifest = "You have access to the following skills (tools). "
        manifest += "To use a skill, respond with JSON in the format: "
        manifest += "{\"type\":\"call_skills\",\"calls\":[{\"skillId\":\"<id>\",\"arguments\":{...}}]}\n"
        manifest += "To respond with text only, use: {\"type\":\"respond\",\"text\":\"<your response>\"}\n\n"
        manifest += "Available skills:\n\n"

        for skill in enabled {
            manifest += "---\n"
            manifest += "ID: \(skill.id)\n"
            manifest += "Name: \(skill.name)\n"
            manifest += "Description: \(skill.description)\n"
            manifest += "Arguments schema:\n\(skill.argumentSchemaJSON)\n\n"
        }

        manifest += "---\n"
        manifest += "IMPORTANT: Always respond with valid JSON. Choose 'respond' for conversational "
        manifest += "replies or 'call_skills' when the user's request matches an available skill.\n"

        return manifest
    }
}
```

### Step 7: Run test to verify it passes

Run: `Cmd+U` or run `SkillsRegistryTests` from Test Navigator
Expected: PASS

### Step 8: Commit

```bash
git add HeyLlama/Services/Skills/SkillsRegistry.swift HeyLlama/Services/Skills/WeatherForecastSkill.swift HeyLlama/Services/Skills/RemindersAddItemSkill.swift HeyLlama/Storage/SkillsConfig.swift HeyLlama/Storage/AssistantConfig.swift HeyLlamaTests/SkillsRegistryTests.swift
git commit -m "feat(skills): add SkillsRegistry with config and placeholder skills"
```

---

## Task 4: Add Skills Permission Checking

**Files:**
- Modify: `HeyLlama/Utilities/Permissions.swift`
- Create: `HeyLlama/Services/Skills/SkillPermissionManager.swift`
- Test: `HeyLlamaTests/SkillPermissionManagerTests.swift`

### Step 1: Write the failing test for SkillPermissionManager

```swift
// HeyLlamaTests/SkillPermissionManagerTests.swift
import XCTest
@testable import HeyLlama

final class SkillPermissionManagerTests: XCTestCase {

    func testCheckRemindersPermissionStatus() async {
        let manager = SkillPermissionManager()
        let status = await manager.checkPermissionStatus(.reminders)

        // Status should be one of the valid values
        XCTAssertTrue([.granted, .denied, .undetermined].contains(status))
    }

    func testCheckLocationPermissionStatus() async {
        let manager = SkillPermissionManager()
        let status = await manager.checkPermissionStatus(.location)

        // Status should be one of the valid values
        XCTAssertTrue([.granted, .denied, .undetermined].contains(status))
    }

    func testCheckAllPermissionsForSkillWithNoPermissions() async {
        let manager = SkillPermissionManager()
        let skill = MockNoPermissionsSkill()

        let allGranted = await manager.checkAllPermissions(for: skill)
        XCTAssertTrue(allGranted, "Skill with no required permissions should return true")
    }

    func testHasAllPermissionsReturnsFalseWhenMissing() async {
        let manager = SkillPermissionManager()

        // Create a skill that requires reminders permission
        let skill = MockRemindersSkill()

        // Check current status - we can't know for sure what it is,
        // but we can verify the method works
        let hasAll = await manager.hasAllPermissions(for: skill)
        let status = await manager.checkPermissionStatus(.reminders)

        if status == .granted {
            XCTAssertTrue(hasAll)
        } else {
            XCTAssertFalse(hasAll)
        }
    }
}

// Test helper skills
struct MockNoPermissionsSkill: Skill {
    var id: String { "test.no_permissions" }
    var name: String { "No Permissions Skill" }
    var description: String { "Test skill with no permissions" }
    var requiredPermissions: [SkillPermission] { [] }
    var argumentSchemaJSON: String { "{}" }

    func run(argumentsJSON: String, context: SkillContext) async throws -> SkillResult {
        SkillResult(text: "Done", data: nil)
    }
}

struct MockRemindersSkill: Skill {
    var id: String { "test.reminders" }
    var name: String { "Test Reminders Skill" }
    var description: String { "Test skill requiring reminders" }
    var requiredPermissions: [SkillPermission] { [.reminders] }
    var argumentSchemaJSON: String { "{}" }

    func run(argumentsJSON: String, context: SkillContext) async throws -> SkillResult {
        SkillResult(text: "Done", data: nil)
    }
}
```

### Step 2: Run test to verify it fails

Run: `Cmd+U` or run `SkillPermissionManagerTests` from Test Navigator
Expected: FAIL with "Cannot find type 'SkillPermissionManager' in scope"

### Step 3: Extend Permissions.swift for Reminders and Location

```swift
// HeyLlama/Utilities/Permissions.swift
// Add these imports and methods to the existing file:

import AVFoundation
import AppKit
import EventKit
import CoreLocation

enum Permissions {

    enum PermissionStatus {
        case granted
        case denied
        case undetermined
    }

    // MARK: - Microphone (existing)

    static func checkMicrophoneStatus() -> PermissionStatus {
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

    // MARK: - Reminders

    static func checkRemindersStatus() -> PermissionStatus {
        let status = EKEventStore.authorizationStatus(for: .reminder)
        switch status {
        case .fullAccess, .authorized:
            return .granted
        case .denied, .restricted:
            return .denied
        case .notDetermined, .writeOnly:
            return .undetermined
        @unknown default:
            return .undetermined
        }
    }

    static func requestRemindersAccess() async -> Bool {
        let store = EKEventStore()
        do {
            return try await store.requestFullAccessToReminders()
        } catch {
            print("Reminders permission error: \(error)")
            return false
        }
    }

    // MARK: - Location

    static func checkLocationStatus() -> PermissionStatus {
        let manager = CLLocationManager()
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            return .granted
        case .denied, .restricted:
            return .denied
        case .notDetermined:
            return .undetermined
        @unknown default:
            return .undetermined
        }
    }

    // Note: Location permission must be requested through CLLocationManager instance
    // which is handled by the LocationService

    // MARK: - System Settings

    static func openSystemSettingsPrivacy() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
    }

    static func openSystemSettingsForPermission(_ permission: SkillPermission) {
        let key = permission.systemSettingsKey
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(key)") {
            NSWorkspace.shared.open(url)
        }
    }
}
```

### Step 4: Write SkillPermissionManager

```swift
// HeyLlama/Services/Skills/SkillPermissionManager.swift
import Foundation

/// Manages permission checking and requesting for skills
actor SkillPermissionManager {

    /// Check the status of a specific permission
    func checkPermissionStatus(_ permission: SkillPermission) -> Permissions.PermissionStatus {
        switch permission {
        case .reminders:
            return Permissions.checkRemindersStatus()
        case .location:
            return Permissions.checkLocationStatus()
        }
    }

    /// Request a specific permission
    func requestPermission(_ permission: SkillPermission) async -> Bool {
        switch permission {
        case .reminders:
            return await Permissions.requestRemindersAccess()
        case .location:
            // Location permission is special - needs CLLocationManager
            // Return current status for now (will be enhanced when we implement location)
            return Permissions.checkLocationStatus() == .granted
        }
    }

    /// Check if all required permissions for a skill are granted
    func hasAllPermissions(for skill: any Skill) async -> Bool {
        for permission in skill.requiredPermissions {
            if checkPermissionStatus(permission) != .granted {
                return false
            }
        }
        return true
    }

    /// Check all permissions for a skill, returns true if all granted or skill has no permissions
    func checkAllPermissions(for skill: any Skill) async -> Bool {
        if skill.requiredPermissions.isEmpty {
            return true
        }
        return await hasAllPermissions(for: skill)
    }

    /// Get list of missing permissions for a skill
    func missingPermissions(for skill: any Skill) -> [SkillPermission] {
        skill.requiredPermissions.filter { checkPermissionStatus($0) != .granted }
    }

    /// Request all missing permissions for a skill
    /// Returns true if all permissions were granted
    func requestAllMissingPermissions(for skill: any Skill) async -> Bool {
        let missing = missingPermissions(for: skill)

        for permission in missing {
            let granted = await requestPermission(permission)
            if !granted {
                return false
            }
        }

        return true
    }
}
```

### Step 5: Run test to verify it passes

Run: `Cmd+U` or run `SkillPermissionManagerTests` from Test Navigator
Expected: PASS

### Step 6: Commit

```bash
git add HeyLlama/Utilities/Permissions.swift HeyLlama/Services/Skills/SkillPermissionManager.swift HeyLlamaTests/SkillPermissionManagerTests.swift
git commit -m "feat(skills): add SkillPermissionManager for permission handling"
```

---

## Task 5: Update LLM Providers for Structured Output

**Files:**
- Modify: `HeyLlama/Services/LLM/LLMServiceProtocol.swift`
- Modify: `HeyLlama/Services/LLM/LLMProviders/OpenAICompatibleProvider.swift`
- Modify: `HeyLlama/Services/LLM/LLMProviders/AppleIntelligenceProvider.swift`
- Test: `HeyLlamaTests/LLMProviderStructuredOutputTests.swift`

### Step 1: Write the failing test for structured output

```swift
// HeyLlamaTests/LLMProviderStructuredOutputTests.swift
import XCTest
@testable import HeyLlama

final class LLMProviderStructuredOutputTests: XCTestCase {

    // MARK: - System Prompt Tests

    func testOpenAIProviderIncludesSkillsManifestInPrompt() {
        let config = OpenAICompatibleConfig(
            enabled: true,
            baseURL: "http://localhost:11434/v1",
            model: "llama3.2"
        )

        let skillsManifest = "Available skills: weather.forecast"
        let systemPrompt = "You are Llama"

        let provider = OpenAICompatibleProvider(
            config: config,
            systemPromptTemplate: systemPrompt
        )

        // Build request body with skills manifest
        let body = provider.buildRequestBody(
            systemPrompt: systemPrompt,
            skillsManifest: skillsManifest,
            prompt: "What's the weather?",
            conversationHistory: []
        )

        let messages = body["messages"] as? [[String: String]]
        XCTAssertNotNil(messages)

        // System message should include skills manifest
        let systemMessage = messages?.first { $0["role"] == "system" }
        XCTAssertNotNil(systemMessage)
        XCTAssertTrue(systemMessage?["content"]?.contains("weather.forecast") ?? false)
    }

    func testOpenAIProviderRequestBodyStructure() {
        let config = OpenAICompatibleConfig(
            enabled: true,
            baseURL: "http://localhost:11434/v1",
            model: "llama3.2"
        )

        let provider = OpenAICompatibleProvider(
            config: config,
            systemPromptTemplate: "You are Llama"
        )

        let body = provider.buildRequestBody(
            systemPrompt: "You are Llama",
            skillsManifest: nil,
            prompt: "Hello",
            conversationHistory: []
        )

        XCTAssertEqual(body["model"] as? String, "llama3.2")
        XCTAssertNotNil(body["messages"])
    }

    // MARK: - Response Format Tests

    func testParseValidJSONResponse() throws {
        let config = OpenAICompatibleConfig(
            enabled: true,
            baseURL: "http://localhost:11434/v1",
            model: "llama3.2"
        )

        let provider = OpenAICompatibleProvider(config: config, systemPromptTemplate: "")

        // Simulate a response that contains JSON
        let responseJSON = """
        {
            "choices": [{
                "message": {
                    "content": "{\\"type\\":\\"respond\\",\\"text\\":\\"Hello!\\"}"
                }
            }]
        }
        """.data(using: .utf8)!

        let content = try provider.parseResponse(responseJSON)
        XCTAssertTrue(content.contains("respond"))
        XCTAssertTrue(content.contains("Hello!"))
    }
}
```

### Step 2: Run test to verify it fails

Run: `Cmd+U` or run `LLMProviderStructuredOutputTests` from Test Navigator
Expected: FAIL - method signature mismatch or missing skillsManifest parameter

### Step 3: Update LLMServiceProtocol with skills manifest support

```swift
// HeyLlama/Services/LLM/LLMServiceProtocol.swift
// Update the protocol to support skills manifest:

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
    ///   - skillsManifest: Optional skills manifest to inject into prompt for structured output
    /// - Returns: The LLM's response text (may be JSON for structured output)
    func complete(
        prompt: String,
        context: CommandContext?,
        conversationHistory: [ConversationTurn],
        skillsManifest: String?
    ) async throws -> String
}

/// Extension with convenience methods
extension LLMServiceProtocol {
    func complete(prompt: String, context: CommandContext?) async throws -> String {
        try await complete(prompt: prompt, context: context, conversationHistory: [], skillsManifest: nil)
    }

    func complete(
        prompt: String,
        context: CommandContext?,
        conversationHistory: [ConversationTurn]
    ) async throws -> String {
        try await complete(prompt: prompt, context: context, conversationHistory: conversationHistory, skillsManifest: nil)
    }
}
```

### Step 4: Update OpenAICompatibleProvider

```swift
// HeyLlama/Services/LLM/LLMProviders/OpenAICompatibleProvider.swift
// Update the complete method and buildRequestBody:

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

        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = TimeInterval(config.timeoutSeconds)
        configuration.timeoutIntervalForResource = TimeInterval(config.timeoutSeconds)
        self.urlSession = URLSession(configuration: configuration)
    }

    func complete(
        prompt: String,
        context: CommandContext?,
        conversationHistory: [ConversationTurn],
        skillsManifest: String?
    ) async throws -> String {
        guard isConfigured else {
            throw LLMError.notConfigured
        }

        let url = try buildURL()
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let apiKey = config.apiKey, !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        let speakerName = context?.speaker?.name
        let systemPrompt = buildSystemPrompt(template: systemPromptTemplate, speakerName: speakerName)

        let body = buildRequestBody(
            systemPrompt: systemPrompt,
            skillsManifest: skillsManifest,
            prompt: prompt,
            conversationHistory: conversationHistory
        )

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await performRequest(request)

        if let httpResponse = response as? HTTPURLResponse {
            guard (200...299).contains(httpResponse.statusCode) else {
                let message = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw LLMError.apiError(statusCode: httpResponse.statusCode, message: message)
            }
        }

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
        skillsManifest: String?,
        prompt: String,
        conversationHistory: [ConversationTurn]
    ) -> [String: Any] {
        var messages: [[String: String]] = []

        // Build full system message with skills manifest if provided
        var fullSystemPrompt = systemPrompt
        if let manifest = skillsManifest {
            fullSystemPrompt += "\n\n--- SKILLS ---\n\(manifest)"
        }

        messages.append([
            "role": "system",
            "content": fullSystemPrompt
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

### Step 5: Update AppleIntelligenceProvider

```swift
// HeyLlama/Services/LLM/LLMProviders/AppleIntelligenceProvider.swift
// Update the complete method to accept skillsManifest:

// ... (keep existing code, just update the complete method signature and implementation)

func complete(
    prompt: String,
    context: CommandContext?,
    conversationHistory: [ConversationTurn],
    skillsManifest: String?
) async throws -> String {
    guard config.enabled else {
        throw LLMError.notConfigured
    }

    guard isAvailable else {
        throw LLMError.providerUnavailable(availabilityReason)
    }

    #if canImport(FoundationModels)
    if #available(macOS 26.0, iOS 26.0, *) {
        return try await performCompletion(
            prompt: prompt,
            context: context,
            conversationHistory: conversationHistory,
            skillsManifest: skillsManifest
        )
    }
    #endif

    throw LLMError.providerUnavailable("Foundation Models not available on this platform")
}

// Update performCompletion to include skillsManifest
#if canImport(FoundationModels)
@available(macOS 26.0, iOS 26.0, *)
private func performCompletion(
    prompt: String,
    context: CommandContext?,
    conversationHistory: [ConversationTurn],
    skillsManifest: String?
) async throws -> String {
    let speakerName = context?.speaker?.name ?? "Guest"
    var systemPrompt = systemPromptTemplate.replacingOccurrences(
        of: "{speaker_name}",
        with: speakerName
    )

    // Append skills manifest if provided
    if let manifest = skillsManifest {
        systemPrompt += "\n\n--- SKILLS ---\n\(manifest)"
    }

    let session = LanguageModelSession {
        systemPrompt
    }

    let fullPrompt = buildPromptWithHistory(prompt: prompt, history: conversationHistory)

    do {
        let response = try await session.respond(to: fullPrompt)
        return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
    } catch {
        throw mapError(error)
    }
}
#endif
```

### Step 6: Update LLMService to pass through skillsManifest

```swift
// HeyLlama/Services/LLM/LLMService.swift
// Update the complete method:

func complete(
    prompt: String,
    context: CommandContext?,
    conversationHistory: [ConversationTurn],
    skillsManifest: String?
) async throws -> String {
    switch config.provider {
    case .appleIntelligence:
        return try await appleIntelligenceProvider.complete(
            prompt: prompt,
            context: context,
            conversationHistory: conversationHistory,
            skillsManifest: skillsManifest
        )
    case .openAICompatible:
        return try await openAICompatibleProvider.complete(
            prompt: prompt,
            context: context,
            conversationHistory: conversationHistory,
            skillsManifest: skillsManifest
        )
    }
}
```

### Step 7: Update MockLLMService

```swift
// HeyLlamaTests/Mocks/MockLLMService.swift
// Update to support skillsManifest:

actor MockLLMService: LLMServiceProtocol {
    private var _isConfigured: Bool = true
    private var mockResponse: String = ""
    private var mockError: Error?

    private(set) var lastPrompt: String?
    private(set) var lastContext: CommandContext?
    private(set) var lastConversationHistory: [ConversationTurn] = []
    private(set) var lastSkillsManifest: String?
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
        conversationHistory: [ConversationTurn],
        skillsManifest: String?
    ) async throws -> String {
        lastPrompt = prompt
        lastContext = context
        lastConversationHistory = conversationHistory
        lastSkillsManifest = skillsManifest
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
        lastSkillsManifest = nil
        completionCount = 0
    }
}
```

### Step 8: Run tests to verify they pass

Run: `Cmd+U` to run all tests
Expected: All tests PASS

### Step 9: Commit

```bash
git add HeyLlama/Services/LLM/LLMServiceProtocol.swift HeyLlama/Services/LLM/LLMService.swift HeyLlama/Services/LLM/LLMProviders/OpenAICompatibleProvider.swift HeyLlama/Services/LLM/LLMProviders/AppleIntelligenceProvider.swift HeyLlamaTests/Mocks/MockLLMService.swift HeyLlamaTests/LLMProviderStructuredOutputTests.swift
git commit -m "feat(llm): add skillsManifest support for structured LLM output"
```

---

## Task 6: Implement Weather Forecast Skill

**Files:**
- Modify: `HeyLlama/Services/Skills/WeatherForecastSkill.swift`
- Modify: `HeyLlama/Info.plist` (add Location usage description)
- Modify: `HeyLlama.entitlements` (add WeatherKit capability)
- Test: `HeyLlamaTests/WeatherForecastSkillTests.swift`

### Step 1: Write the failing test for WeatherForecastSkill

```swift
// HeyLlamaTests/WeatherForecastSkillTests.swift
import XCTest
@testable import HeyLlama

final class WeatherForecastSkillTests: XCTestCase {

    func testSkillHasCorrectId() {
        let skill = WeatherForecastSkill()
        XCTAssertEqual(skill.id, "weather.forecast")
    }

    func testSkillRequiresLocationPermission() {
        let skill = WeatherForecastSkill()
        XCTAssertTrue(skill.requiredPermissions.contains(.location))
    }

    func testArgumentSchemaIsValidJSON() {
        let skill = WeatherForecastSkill()
        let schemaData = skill.argumentSchemaJSON.data(using: .utf8)!

        XCTAssertNoThrow(try JSONSerialization.jsonObject(with: schemaData))
    }

    func testParseWeatherArguments() throws {
        let skill = WeatherForecastSkill()

        let args = try skill.parseArguments(from: """
        {"when": "today", "location": "San Francisco"}
        """)

        XCTAssertEqual(args.when, .today)
        XCTAssertEqual(args.location, "San Francisco")
    }

    func testParseWeatherArgumentsWithoutLocation() throws {
        let skill = WeatherForecastSkill()

        let args = try skill.parseArguments(from: """
        {"when": "tomorrow"}
        """)

        XCTAssertEqual(args.when, .tomorrow)
        XCTAssertNil(args.location)
    }

    func testParseWeatherArgumentsInvalidWhen() {
        let skill = WeatherForecastSkill()

        XCTAssertThrowsError(try skill.parseArguments(from: """
        {"when": "invalid"}
        """))
    }

    func testParseWeatherArgumentsMissingWhen() {
        let skill = WeatherForecastSkill()

        XCTAssertThrowsError(try skill.parseArguments(from: """
        {"location": "Paris"}
        """))
    }
}
```

### Step 2: Run test to verify it fails

Run: `Cmd+U` or run `WeatherForecastSkillTests` from Test Navigator
Expected: FAIL - parseArguments method doesn't exist

### Step 3: Update Info.plist with location usage description

Add to `HeyLlama/Info.plist`:

```xml
<key>NSLocationUsageDescription</key>
<string>HeyLlama needs your location to provide accurate weather forecasts.</string>
<key>NSLocationWhenInUseUsageDescription</key>
<string>HeyLlama needs your location to provide accurate weather forecasts.</string>
```

### Step 4: Add WeatherKit entitlement

Add to `HeyLlama.entitlements`:

```xml
<key>com.apple.developer.weatherkit</key>
<true/>
```

Note: You also need to enable WeatherKit capability in Xcode project settings and register the App ID with WeatherKit in the Apple Developer Portal.

### Step 5: Implement WeatherForecastSkill

```swift
// HeyLlama/Services/Skills/WeatherForecastSkill.swift
import Foundation
import WeatherKit
import CoreLocation

/// Weather forecast skill using WeatherKit
struct WeatherForecastSkill: Skill {
    var id: String { "weather.forecast" }
    var name: String { "Weather Forecast" }
    var description: String { "Get the weather forecast for today, tomorrow, or the next 7 days" }
    var requiredPermissions: [SkillPermission] { [.location] }

    var argumentSchemaJSON: String {
        """
        {
            "type": "object",
            "properties": {
                "when": {
                    "type": "string",
                    "enum": ["today", "tomorrow", "next_7_days"],
                    "description": "The time period for the forecast"
                },
                "location": {
                    "type": "string",
                    "description": "Optional location name. If omitted, uses current location."
                }
            },
            "required": ["when"]
        }
        """
    }

    // MARK: - Argument Parsing

    enum TimePeriod: String, Codable {
        case today
        case tomorrow
        case next_7_days
    }

    struct Arguments: Codable {
        let when: TimePeriod
        let location: String?
    }

    func parseArguments(from json: String) throws -> Arguments {
        guard let data = json.data(using: .utf8) else {
            throw SkillError.invalidArguments("Invalid JSON encoding")
        }

        do {
            return try JSONDecoder().decode(Arguments.self, from: data)
        } catch {
            throw SkillError.invalidArguments("Failed to parse arguments: \(error.localizedDescription)")
        }
    }

    // MARK: - Execution

    func run(argumentsJSON: String, context: SkillContext) async throws -> SkillResult {
        let args = try parseArguments(from: argumentsJSON)

        // Get location
        let location: CLLocation
        if let locationName = args.location {
            location = try await geocodeLocation(locationName)
        } else {
            location = try await getCurrentLocation()
        }

        // Fetch weather
        let weatherService = WeatherService.shared
        let weather = try await weatherService.weather(for: location)

        // Format response based on time period
        let responseText = formatWeatherResponse(weather: weather, period: args.when, locationName: args.location)

        return SkillResult(text: responseText, data: [
            "temperature": weather.currentWeather.temperature.value,
            "temperatureUnit": weather.currentWeather.temperature.unit.symbol,
            "condition": weather.currentWeather.condition.description
        ])
    }

    // MARK: - Private Helpers

    private func geocodeLocation(_ name: String) async throws -> CLLocation {
        let geocoder = CLGeocoder()
        let placemarks = try await geocoder.geocodeAddressString(name)

        guard let placemark = placemarks.first,
              let location = placemark.location else {
            throw SkillError.executionFailed("Could not find location: \(name)")
        }

        return location
    }

    private func getCurrentLocation() async throws -> CLLocation {
        // Use a simple location manager to get current location
        let locationManager = SimpleLocationManager()
        return try await locationManager.getCurrentLocation()
    }

    private func formatWeatherResponse(weather: Weather, period: TimePeriod, locationName: String?) -> String {
        let locationStr = locationName ?? "your location"
        let current = weather.currentWeather

        switch period {
        case .today:
            let temp = current.temperature.formatted()
            let condition = current.condition.description
            let high = weather.dailyForecast.first?.highTemperature.formatted() ?? "N/A"
            let low = weather.dailyForecast.first?.lowTemperature.formatted() ?? "N/A"

            return "The weather in \(locationStr) today is \(condition) with a current temperature of \(temp). Expected high of \(high) and low of \(low)."

        case .tomorrow:
            guard weather.dailyForecast.count > 1 else {
                return "Tomorrow's forecast is not available."
            }
            let tomorrow = weather.dailyForecast[1]
            let condition = tomorrow.condition.description
            let high = tomorrow.highTemperature.formatted()
            let low = tomorrow.lowTemperature.formatted()

            return "Tomorrow in \(locationStr) will be \(condition) with a high of \(high) and low of \(low)."

        case .next_7_days:
            var forecast = "Here's the 7-day forecast for \(locationStr):\n"
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "EEEE"

            for (index, day) in weather.dailyForecast.prefix(7).enumerated() {
                let dayName = index == 0 ? "Today" : dateFormatter.string(from: day.date)
                let condition = day.condition.description
                let high = day.highTemperature.formatted()
                let low = day.lowTemperature.formatted()
                forecast += "• \(dayName): \(condition), \(high)/\(low)\n"
            }

            return forecast
        }
    }
}

// MARK: - Simple Location Manager

/// Simple wrapper to get current location once
private actor SimpleLocationManager: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation, Error>?

    func getCurrentLocation() async throws -> CLLocation {
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation

            Task { @MainActor in
                self.manager.delegate = self
                self.manager.desiredAccuracy = kCLLocationAccuracyKilometer
                self.manager.requestWhenInUseAuthorization()
                self.manager.requestLocation()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else { return }
        Task {
            await self.handleLocation(location)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task {
            await self.handleError(error)
        }
    }

    private func handleLocation(_ location: CLLocation) {
        continuation?.resume(returning: location)
        continuation = nil
    }

    private func handleError(_ error: Error) {
        continuation?.resume(throwing: SkillError.executionFailed("Location error: \(error.localizedDescription)"))
        continuation = nil
    }
}
```

### Step 6: Run test to verify it passes

Run: `Cmd+U` or run `WeatherForecastSkillTests` from Test Navigator
Expected: PASS for parsing tests (actual weather fetching tests may need network/location access)

### Step 7: Commit

```bash
git add HeyLlama/Services/Skills/WeatherForecastSkill.swift HeyLlama/Info.plist HeyLlama/HeyLlama.entitlements HeyLlamaTests/WeatherForecastSkillTests.swift
git commit -m "feat(skills): implement WeatherForecastSkill with WeatherKit"
```

---

## Task 7: Implement Reminders Add Item Skill

**Files:**
- Modify: `HeyLlama/Services/Skills/RemindersAddItemSkill.swift`
- Modify: `HeyLlama/Info.plist` (add Reminders usage description)
- Test: `HeyLlamaTests/RemindersAddItemSkillTests.swift`

### Step 1: Write the failing test for RemindersAddItemSkill

```swift
// HeyLlamaTests/RemindersAddItemSkillTests.swift
import XCTest
@testable import HeyLlama

final class RemindersAddItemSkillTests: XCTestCase {

    func testSkillHasCorrectId() {
        let skill = RemindersAddItemSkill()
        XCTAssertEqual(skill.id, "reminders.add_item")
    }

    func testSkillRequiresRemindersPermission() {
        let skill = RemindersAddItemSkill()
        XCTAssertTrue(skill.requiredPermissions.contains(.reminders))
    }

    func testArgumentSchemaIsValidJSON() {
        let skill = RemindersAddItemSkill()
        let schemaData = skill.argumentSchemaJSON.data(using: .utf8)!

        XCTAssertNoThrow(try JSONSerialization.jsonObject(with: schemaData))
    }

    func testParseRemindersArguments() throws {
        let skill = RemindersAddItemSkill()

        let args = try skill.parseArguments(from: """
        {"listName": "Groceries", "itemName": "Milk"}
        """)

        XCTAssertEqual(args.listName, "Groceries")
        XCTAssertEqual(args.itemName, "Milk")
        XCTAssertNil(args.notes)
        XCTAssertNil(args.dueDateISO8601)
    }

    func testParseRemindersArgumentsWithOptionalFields() throws {
        let skill = RemindersAddItemSkill()

        let args = try skill.parseArguments(from: """
        {
            "listName": "Shopping",
            "itemName": "Bread",
            "notes": "Whole wheat",
            "dueDateISO8601": "2026-02-03T10:00:00Z"
        }
        """)

        XCTAssertEqual(args.listName, "Shopping")
        XCTAssertEqual(args.itemName, "Bread")
        XCTAssertEqual(args.notes, "Whole wheat")
        XCTAssertEqual(args.dueDateISO8601, "2026-02-03T10:00:00Z")
    }

    func testParseRemindersArgumentsMissingRequired() {
        let skill = RemindersAddItemSkill()

        // Missing itemName
        XCTAssertThrowsError(try skill.parseArguments(from: """
        {"listName": "Groceries"}
        """))

        // Missing listName
        XCTAssertThrowsError(try skill.parseArguments(from: """
        {"itemName": "Milk"}
        """))
    }
}
```

### Step 2: Run test to verify it fails

Run: `Cmd+U` or run `RemindersAddItemSkillTests` from Test Navigator
Expected: FAIL - parseArguments method doesn't exist

### Step 3: Update Info.plist with reminders usage description

Add to `HeyLlama/Info.plist`:

```xml
<key>NSRemindersFullAccessUsageDescription</key>
<string>HeyLlama needs access to Reminders to add items to your lists.</string>
```

### Step 4: Implement RemindersAddItemSkill

```swift
// HeyLlama/Services/Skills/RemindersAddItemSkill.swift
import Foundation
import EventKit

/// Skill to add items to Reminders lists
struct RemindersAddItemSkill: Skill {
    var id: String { "reminders.add_item" }
    var name: String { "Add Reminder" }
    var description: String { "Add an item to a Reminders list (e.g., 'add milk to the groceries list')" }
    var requiredPermissions: [SkillPermission] { [.reminders] }

    var argumentSchemaJSON: String {
        """
        {
            "type": "object",
            "properties": {
                "listName": {
                    "type": "string",
                    "description": "The name of the Reminders list to add to (e.g., 'Groceries', 'Shopping', 'To Do')"
                },
                "itemName": {
                    "type": "string",
                    "description": "The item/reminder to add"
                },
                "notes": {
                    "type": "string",
                    "description": "Optional notes for the reminder"
                },
                "dueDateISO8601": {
                    "type": "string",
                    "description": "Optional due date in ISO8601 format (e.g., '2026-02-03T10:00:00Z')"
                }
            },
            "required": ["listName", "itemName"]
        }
        """
    }

    // MARK: - Argument Parsing

    struct Arguments: Codable {
        let listName: String
        let itemName: String
        let notes: String?
        let dueDateISO8601: String?
    }

    func parseArguments(from json: String) throws -> Arguments {
        guard let data = json.data(using: .utf8) else {
            throw SkillError.invalidArguments("Invalid JSON encoding")
        }

        do {
            return try JSONDecoder().decode(Arguments.self, from: data)
        } catch {
            throw SkillError.invalidArguments("Failed to parse arguments: \(error.localizedDescription)")
        }
    }

    // MARK: - Execution

    func run(argumentsJSON: String, context: SkillContext) async throws -> SkillResult {
        let args = try parseArguments(from: argumentsJSON)

        // Check permission
        let status = Permissions.checkRemindersStatus()
        guard status == .granted else {
            if status == .undetermined {
                let granted = await Permissions.requestRemindersAccess()
                guard granted else {
                    throw SkillError.permissionDenied(.reminders)
                }
            } else {
                throw SkillError.permissionDenied(.reminders)
            }
        }

        let eventStore = EKEventStore()

        // Find the target list
        let calendars = eventStore.calendars(for: .reminder)
        guard let targetCalendar = calendars.first(where: {
            $0.title.localizedCaseInsensitiveCompare(args.listName) == .orderedSame
        }) else {
            let availableLists = calendars.map { $0.title }.joined(separator: ", ")
            throw SkillError.executionFailed(
                "Could not find a Reminders list named '\(args.listName)'. " +
                "Available lists: \(availableLists)"
            )
        }

        // Create the reminder
        let reminder = EKReminder(eventStore: eventStore)
        reminder.title = args.itemName
        reminder.calendar = targetCalendar

        if let notes = args.notes {
            reminder.notes = notes
        }

        if let dueDateString = args.dueDateISO8601 {
            let formatter = ISO8601DateFormatter()
            if let dueDate = formatter.date(from: dueDateString) {
                reminder.dueDateComponents = Calendar.current.dateComponents(
                    [.year, .month, .day, .hour, .minute],
                    from: dueDate
                )
            }
        }

        // Save the reminder
        do {
            try eventStore.save(reminder, commit: true)
        } catch {
            throw SkillError.executionFailed("Failed to save reminder: \(error.localizedDescription)")
        }

        // Build response
        var response = "Added '\(args.itemName)' to your \(args.listName) list"
        if let notes = args.notes {
            response += " with notes: \(notes)"
        }
        if args.dueDateISO8601 != nil {
            response += " with a due date"
        }
        response += "."

        return SkillResult(
            text: response,
            data: [
                "listName": args.listName,
                "itemName": args.itemName,
                "reminderId": reminder.calendarItemIdentifier
            ]
        )
    }
}
```

### Step 5: Run test to verify it passes

Run: `Cmd+U` or run `RemindersAddItemSkillTests` from Test Navigator
Expected: PASS for parsing tests

### Step 6: Commit

```bash
git add HeyLlama/Services/Skills/RemindersAddItemSkill.swift HeyLlama/Info.plist HeyLlamaTests/RemindersAddItemSkillTests.swift
git commit -m "feat(skills): implement RemindersAddItemSkill with EventKit"
```

---

## Task 8: Integrate Skills into AssistantCoordinator

**Files:**
- Modify: `HeyLlama/Core/AssistantCoordinator.swift`
- Test: `HeyLlamaTests/AssistantCoordinatorSkillsTests.swift`

### Step 1: Write the failing test for skills integration

```swift
// HeyLlamaTests/AssistantCoordinatorSkillsTests.swift
import XCTest
@testable import HeyLlama

@MainActor
final class AssistantCoordinatorSkillsTests: XCTestCase {

    func testCoordinatorHasSkillsRegistry() async {
        let coordinator = AssistantCoordinator()
        XCTAssertNotNil(coordinator.skillsRegistry)
    }

    func testProcessActionPlanRespond() async throws {
        let mockLLM = MockLLMService()
        await mockLLM.setMockResponse("""
        {"type":"respond","text":"Hello! How can I help?"}
        """)

        let coordinator = AssistantCoordinator(llmService: mockLLM)

        // Simulate processing a command that results in a respond action
        // The coordinator should parse the JSON and extract the text
        let result = try await coordinator.processActionPlan(
            from: """
            {"type":"respond","text":"Hello! How can I help?"}
            """
        )

        XCTAssertEqual(result, "Hello! How can I help?")
    }

    func testProcessActionPlanCallSkillDisabled() async {
        let coordinator = AssistantCoordinator()

        // Try to call a disabled skill
        let result = try? await coordinator.processActionPlan(
            from: """
            {"type":"call_skills","calls":[{"skillId":"weather.forecast","arguments":{"when":"today"}}]}
            """
        )

        // Should return an error message since skill is disabled
        XCTAssertNotNil(result)
        XCTAssertTrue(result?.contains("disabled") ?? false)
    }

    func testSkillsManifestGeneratedForEnabledSkills() async {
        var config = AssistantConfig.default
        config.skills.enabledSkillIds = ["weather.forecast"]

        let coordinator = AssistantCoordinator()
        coordinator.updateSkillsConfig(config.skills)

        let manifest = coordinator.skillsRegistry.generateSkillsManifest()
        XCTAssertTrue(manifest.contains("weather.forecast"))
        XCTAssertFalse(manifest.contains("reminders.add_item"))
    }
}
```

### Step 2: Run test to verify it fails

Run: `Cmd+U` or run `AssistantCoordinatorSkillsTests` from Test Navigator
Expected: FAIL - skillsRegistry property and processActionPlan method don't exist

### Step 3: Update AssistantCoordinator with skills support

```swift
// HeyLlama/Core/AssistantCoordinator.swift
// Add skills support to the existing AssistantCoordinator

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

    // ADD: Skills support
    let skillsRegistry: SkillsRegistry
    private let permissionManager: SkillPermissionManager

    private let audioEngine: AudioEngine
    private let vadService: VADService
    private let audioBuffer: AudioBuffer
    private let sttService: any STTServiceProtocol
    private let speakerService: any SpeakerServiceProtocol
    private var llmService: any LLMServiceProtocol
    private let commandProcessor: CommandProcessor
    private let speakerStore: SpeakerStore
    private let configStore: ConfigStore
    private var conversationManager: ConversationManager
    private var cancellables = Set<AnyCancellable>()
    private var useInjectedLLMService: Bool = false

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

        // Initialize skills
        self.skillsRegistry = SkillsRegistry(config: config.skills)
        self.permissionManager = SkillPermissionManager()

        // Track if LLM service was injected (for testing)
        if let injectedLLM = llmService {
            self.llmService = injectedLLM
            self.useInjectedLLMService = true
        } else {
            self.llmService = LLMService(config: config.llm)
            self.useInjectedLLMService = false
        }

        self.commandProcessor = CommandProcessor(wakePhrase: config.wakePhrase)
        self.speakerStore = SpeakerStore()
        self.conversationManager = ConversationManager(
            timeoutMinutes: config.llm.conversationTimeoutMinutes,
            maxTurns: config.llm.maxConversationTurns
        )

        self.requiresOnboarding = !speakerStore.hasSpeakers()

        setupBindings()
    }

    // ... (keep existing setupBindings, lifecycle, speaker management methods)

    // ADD: Skills configuration update
    func updateSkillsConfig(_ newConfig: SkillsConfig) {
        skillsRegistry.updateConfig(newConfig)
    }

    // MARK: - Command Processing (updated)

    private func processCommand(_ commandText: String, speaker: Speaker?, source: AudioSource) async {
        state = .responding

        let context = CommandContext(
            command: commandText,
            speaker: speaker,
            source: source,
            conversationHistory: conversationManager.getRecentHistory()
        )

        let history = conversationManager.getRecentHistory()

        // Generate skills manifest for enabled skills
        let skillsManifest = skillsRegistry.generateSkillsManifest()

        do {
            // Call LLM with skills manifest
            let llmResponse = try await llmService.complete(
                prompt: commandText,
                context: context,
                conversationHistory: history,
                skillsManifest: skillsManifest.isEmpty ? nil : skillsManifest
            )

            // Process the action plan
            let finalResponse = try await processActionPlan(from: llmResponse)

            // Update conversation history
            conversationManager.addTurn(role: .user, content: commandText)
            conversationManager.addTurn(role: .assistant, content: finalResponse)

            // Update UI
            lastResponse = finalResponse
            print("Response: \(finalResponse)")

        } catch let error as LLMError {
            print("LLM Error: \(error.localizedDescription)")
            lastResponse = "[Error: \(error.localizedDescription)]"
        } catch let error as SkillError {
            print("Skill Error: \(error.localizedDescription)")
            lastResponse = "[Error: \(error.localizedDescription)]"
        } catch {
            print("Unexpected error: \(error)")
            lastResponse = "[Error processing command]"
        }

        state = .listening
    }

    // ADD: Process LLM action plan
    func processActionPlan(from response: String) async throws -> String {
        // Try to parse as JSON action plan
        do {
            let plan = try LLMActionPlan.parse(from: response)

            switch plan {
            case .respond(let text):
                return text

            case .callSkills(let calls):
                return try await executeSkillCalls(calls)
            }
        } catch {
            // If parsing fails, treat the response as plain text
            // This handles cases where the LLM doesn't return valid JSON
            print("Failed to parse action plan, treating as plain text: \(error)")
            return response
        }
    }

    // ADD: Execute skill calls
    private func executeSkillCalls(_ calls: [SkillCall]) async throws -> String {
        var results: [String] = []

        for call in calls {
            guard let skill = skillsRegistry.skill(withId: call.skillId) else {
                results.append("I couldn't find the skill '\(call.skillId)'.")
                continue
            }

            guard skillsRegistry.isSkillEnabled(call.skillId) else {
                results.append("The \(skill.name) skill is currently disabled. You can enable it in Settings.")
                continue
            }

            // Check permissions
            let hasPermissions = await permissionManager.hasAllPermissions(for: skill)
            if !hasPermissions {
                let missing = permissionManager.missingPermissions(for: skill)
                let missingNames = missing.map { $0.displayName }.joined(separator: ", ")
                results.append("The \(skill.name) skill requires \(missingNames) permission. Please grant access in Settings.")
                continue
            }

            // Execute the skill
            do {
                let argsJSON = try call.argumentsAsJSON()
                let context = SkillContext(
                    speaker: currentSpeaker,
                    source: .localMic
                )
                let result = try await skill.run(argumentsJSON: argsJSON, context: context)
                results.append(result.text)
            } catch let error as SkillError {
                results.append("Error with \(skill.name): \(error.localizedDescription)")
            } catch {
                results.append("An error occurred while running \(skill.name).")
            }
        }

        return results.joined(separator: " ")
    }

    // ... (keep all other existing methods)
}
```

### Step 4: Run tests to verify they pass

Run: `Cmd+U` to run all tests
Expected: PASS

### Step 5: Commit

```bash
git add HeyLlama/Core/AssistantCoordinator.swift HeyLlamaTests/AssistantCoordinatorSkillsTests.swift
git commit -m "feat(skills): integrate SkillsRegistry into AssistantCoordinator"
```

---

## Task 9: Create Skills Settings UI

**Files:**
- Create: `HeyLlama/UI/Settings/SkillsSettingsView.swift`
- Modify: `HeyLlama/UI/Settings/SettingsView.swift`

### Step 1: Create SkillsSettingsView

```swift
// HeyLlama/UI/Settings/SkillsSettingsView.swift
import SwiftUI

struct SkillsSettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var config: AssistantConfig
    @State private var isSaving = false
    @State private var saveError: String?

    private let configStore: ConfigStore
    private let skillsRegistry = SkillsRegistry()
    private let permissionManager = SkillPermissionManager()

    init() {
        let store = ConfigStore()
        self.configStore = store
        self._config = State(initialValue: store.loadConfig())
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Header
                    Text("Skills allow the assistant to perform actions like checking weather or adding reminders. Enable the skills you want to use.")
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 8)

                    // Skills list
                    ForEach(skillsRegistry.allSkills, id: \.id) { skill in
                        SkillRow(
                            skill: skill,
                            isEnabled: config.skills.enabledSkillIds.contains(skill.id),
                            permissionManager: permissionManager,
                            onToggle: { enabled in
                                toggleSkill(skill.id, enabled: enabled)
                            }
                        )
                    }
                }
                .padding(16)
            }

            // Footer
            Divider()

            HStack {
                if let error = saveError {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundColor(.red)
                        .font(.caption)
                }

                Spacer()

                Button("Save") {
                    saveConfig()
                }
                .disabled(isSaving)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    private func toggleSkill(_ skillId: String, enabled: Bool) {
        if enabled {
            if !config.skills.enabledSkillIds.contains(skillId) {
                config.skills.enabledSkillIds.append(skillId)
            }
        } else {
            config.skills.enabledSkillIds.removeAll { $0 == skillId }
        }
    }

    private func saveConfig() {
        isSaving = true
        saveError = nil

        do {
            try configStore.saveConfig(config)

            Task {
                await appState.reloadConfig()
                isSaving = false
            }
        } catch {
            saveError = error.localizedDescription
            isSaving = false
        }
    }
}

// MARK: - Skill Row

struct SkillRow: View {
    let skill: any Skill
    let isEnabled: Bool
    let permissionManager: SkillPermissionManager
    let onToggle: (Bool) -> Void

    @State private var permissionStatuses: [SkillPermission: Permissions.PermissionStatus] = [:]

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(skill.name)
                            .font(.headline)

                        Text(skill.description)
                            .font(.callout)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Toggle("", isOn: Binding(
                        get: { isEnabled },
                        set: { newValue in
                            if newValue {
                                // Check permissions before enabling
                                requestPermissionsIfNeeded()
                            }
                            onToggle(newValue)
                        }
                    ))
                    .labelsHidden()
                }

                // Permission indicators
                if !skill.requiredPermissions.isEmpty {
                    Divider()

                    HStack(spacing: 12) {
                        Text("Requires:")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        ForEach(skill.requiredPermissions, id: \.rawValue) { permission in
                            PermissionBadge(
                                permission: permission,
                                status: permissionStatuses[permission] ?? .undetermined
                            )
                        }

                        Spacer()
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .task {
            await loadPermissionStatuses()
        }
    }

    private func loadPermissionStatuses() async {
        for permission in skill.requiredPermissions {
            let status = await permissionManager.checkPermissionStatus(permission)
            await MainActor.run {
                permissionStatuses[permission] = status
            }
        }
    }

    private func requestPermissionsIfNeeded() {
        Task {
            _ = await permissionManager.requestAllMissingPermissions(for: skill)
            await loadPermissionStatuses()
        }
    }
}

// MARK: - Permission Badge

struct PermissionBadge: View {
    let permission: SkillPermission
    let status: Permissions.PermissionStatus

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: statusIcon)
                .foregroundColor(statusColor)

            Text(permission.displayName)
                .font(.caption)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(statusColor.opacity(0.1))
        .cornerRadius(4)
        .onTapGesture {
            if status == .denied {
                Permissions.openSystemSettingsForPermission(permission)
            }
        }
    }

    private var statusIcon: String {
        switch status {
        case .granted:
            return "checkmark.circle.fill"
        case .denied:
            return "xmark.circle.fill"
        case .undetermined:
            return "questionmark.circle"
        }
    }

    private var statusColor: Color {
        switch status {
        case .granted:
            return .green
        case .denied:
            return .red
        case .undetermined:
            return .orange
        }
    }
}

#Preview {
    SkillsSettingsView()
        .environmentObject(AppState())
        .frame(width: 480, height: 400)
}
```

### Step 2: Update SettingsView to include Skills tab

```swift
// HeyLlama/UI/Settings/SettingsView.swift
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

            SkillsSettingsView()  // ADD THIS
                .tabItem {
                    Label("Skills", systemImage: "wand.and.stars")
                }

            AudioSettingsPlaceholder()
                .tabItem {
                    Label("Audio", systemImage: "waveform")
                }

            SpeakersSettingsView()
                .tabItem {
                    Label("Speakers", systemImage: "person.2")
                }

            APISettingsPlaceholder()
                .tabItem {
                    Label("API", systemImage: "network")
                }
        }
        .frame(width: 480, height: 520)
    }
}

// ... (keep rest of file unchanged)
```

### Step 3: Build to verify no errors

Run: `Cmd+B`
Expected: Build succeeds

### Step 4: Commit

```bash
git add HeyLlama/UI/Settings/SkillsSettingsView.swift HeyLlama/UI/Settings/SettingsView.swift
git commit -m "feat(ui): add Skills settings view with permission management"
```

---

## Task 10: Add Files to Xcode Project

**Files:**
- Modify: `HeyLlama.xcodeproj/project.pbxproj`

### Step 1: Open Xcode and add all new files to project

In Xcode:
1. Right-click on `HeyLlama/Services` folder in Project Navigator
2. Create new group "Skills"
3. Add existing files to the Skills group:
   - `SkillProtocol.swift`
   - `SkillPermission.swift`
   - `SkillsRegistry.swift`
   - `SkillPermissionManager.swift`
   - `WeatherForecastSkill.swift`
   - `RemindersAddItemSkill.swift`

4. Add `LLMActionPlan.swift` to `HeyLlama/Models` group

5. Add `SkillsConfig.swift` to `HeyLlama/Storage` group

6. Add `SkillsSettingsView.swift` to `HeyLlama/UI/Settings` group

7. In test target, add:
   - `SkillProtocolTests.swift`
   - `LLMActionPlanTests.swift`
   - `SkillsRegistryTests.swift`
   - `SkillPermissionManagerTests.swift`
   - `WeatherForecastSkillTests.swift`
   - `RemindersAddItemSkillTests.swift`
   - `AssistantCoordinatorSkillsTests.swift`
   - `LLMProviderStructuredOutputTests.swift`

### Step 2: Build and run all tests

Run: `Cmd+U`
Expected: All tests PASS

### Step 3: Commit

```bash
git add HeyLlama.xcodeproj/project.pbxproj
git commit -m "chore: add skills files to Xcode project"
```

---

## Task 11: Integration Testing and Manual Verification

### Step 1: Run full test suite

Run: `Cmd+U` in Xcode
Expected: All tests PASS

### Step 2: Manual testing checklist

1. **Settings UI:**
   - [ ] Open Settings window (`Cmd+,`)
   - [ ] Navigate to "Skills" tab
   - [ ] Verify Weather and Reminders skills are listed
   - [ ] Verify both are disabled by default
   - [ ] Enable Weather skill - verify location permission prompt appears
   - [ ] Enable Reminders skill - verify reminders permission prompt appears
   - [ ] Save settings
   - [ ] Close and reopen Settings - verify enabled state persists

2. **Weather Skill:**
   - [ ] Enable Weather skill in Settings
   - [ ] Grant location permission
   - [ ] Say "Hey Llama, what's the weather?"
   - [ ] Verify LLM returns a call_skills action
   - [ ] Verify weather data is fetched and displayed

3. **Reminders Skill:**
   - [ ] Enable Reminders skill in Settings
   - [ ] Grant reminders permission
   - [ ] Create a "Groceries" list in Reminders app if not exists
   - [ ] Say "Hey Llama, add milk to the groceries list"
   - [ ] Verify item appears in Reminders app

4. **Disabled Skill Handling:**
   - [ ] Disable Weather skill
   - [ ] Say "Hey Llama, what's the weather?"
   - [ ] Verify assistant responds that the skill is disabled

5. **Permission Denied Handling:**
   - [ ] Deny location permission in System Settings
   - [ ] Say "Hey Llama, what's the weather?"
   - [ ] Verify assistant responds with permission error message

### Step 3: Final commit

```bash
git add .
git commit -m "Milestone 5: tools/skills registry with Weather and Reminders

- Add Skill protocol and SkillPermission types
- Add LLMActionPlan model for structured JSON output
- Add SkillsRegistry with config and placeholder skills
- Add SkillPermissionManager for permission handling
- Update LLM providers to support skills manifest
- Implement WeatherForecastSkill with WeatherKit
- Implement RemindersAddItemSkill with EventKit
- Integrate SkillsRegistry into AssistantCoordinator
- Add Skills settings UI with permission management
- Add comprehensive test coverage"
```

---

## Summary

This plan implements Milestone 5 (Tools/Skills Registry) with:

1. **Skill Protocol** - A common interface for all skills with ID, name, description, required permissions, JSON schema, and run method

2. **SkillsRegistry** - Central registry holding all available skills, managing enabled state from config, and generating prompt manifests

3. **LLMActionPlan** - JSON parsing model supporting `respond` (plain text) and `call_skills` (skill invocation) actions

4. **Permission Management** - SkillPermissionManager checks and requests permissions for Location (weather) and Reminders

5. **Weather Skill** - Uses WeatherKit and CoreLocation to provide today/tomorrow/7-day forecasts

6. **Reminders Skill** - Uses EventKit to add items to existing Reminders lists

7. **Settings UI** - Skills tab with toggles, permission status badges, and save functionality

8. **LLM Integration** - Updated providers inject skills manifest into system prompt for structured output

The architecture is designed to be easily extensible - adding new skills requires only:
1. Create a new struct conforming to `Skill`
2. Add it to the `registeredSkills` array in `SkillsRegistry`
3. Add any new permissions to `SkillPermission` enum

---

**Plan complete and saved to `docs/plans/2026-02-02-tools-registry.md`. Two execution options:**

**1. Subagent-Driven (this session)** - I dispatch fresh subagent per task, review between tasks, fast iteration

**2. Parallel Session (separate)** - Open new session with executing-plans, batch execution with checkpoints

**Which approach?**
