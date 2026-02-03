# Skill Architecture Design

## Overview

This document describes the architecture for skills (function calls) in Hey Llama, supporting both Apple Intelligence (via guided generation) and OpenAI-compatible providers (via JSON schemas).

## Problem Statement

Skills need structured arguments extracted from natural language. Apple's Foundation Models use `@Generable` Swift structs with guided generation, while OpenAI-compatible providers use JSON schemas. The current implementation has:

- Hardcoded Tool structs in `AppleIntelligenceProvider`
- JSON schemas in `SkillsRegistry` enum
- Separate argument structs in skill files
- Duplication across 3+ files when adding a skill

This doesn't scale as we add more skills (calendar, messages, email, etc.).

## Design Goals

1. **Single source of truth**: Each skill fully self-contained in one file
2. **Dual provider support**: Works with both Apple Intelligence and OpenAI-compatible providers
3. **Identical execution**: Same skill logic runs regardless of LLM provider
4. **Explicit over magic**: No runtime reflection or code generation
5. **Test-verified**: Tests ensure Swift structs and JSON schemas stay in sync
6. **Well-documented**: Clear guide for adding new skills

## Architecture

### Skill Protocol

Every skill conforms to a single protocol:

```swift
protocol Skill {
    /// Unique identifier (e.g., "weather.forecast")
    static var id: String { get }

    /// Human-readable name (e.g., "Weather Forecast")
    static var name: String { get }

    /// Description for LLM to understand when to use this skill
    static var description: String { get }

    /// System permissions required (e.g., [.location])
    static var requiredPermissions: [SkillPermission] { get }

    /// Whether ResponseAgent should synthesize a natural response
    static var includesInResponseAgent: Bool { get }

    /// JSON schema for OpenAI-compatible providers
    static var argumentsJSONSchema: String { get }

    /// The @Generable arguments type for Apple's guided generation
    associatedtype Arguments: Codable, Sendable

    /// Execute the skill with parsed arguments
    func execute(arguments: Arguments, context: SkillContext) async throws -> SkillResult
}
```

### Skill File Structure

Each skill is completely self-contained in a single file:

```swift
import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Skill Definition

struct WeatherForecastSkill: Skill {
    static let id = "weather.forecast"
    static let name = "Weather Forecast"
    static let description = "Get the weather forecast for today, tomorrow, or the next 7 days"
    static let requiredPermissions: [SkillPermission] = [.location]
    static let includesInResponseAgent = true

    // MARK: - Arguments (Source of Truth for Structure)

    /// Argument struct used by both Apple (via @Generable) and OpenAI (via JSON schema).
    /// IMPORTANT: When modifying this struct, you MUST update argumentsJSONSchema
    /// to match. Run tests to verify they stay in sync.
    @Generable
    struct Arguments: Codable, Sendable {
        @Guide(description: "Time period for forecast", .anyOf(["today", "tomorrow", "next_7_days"]))
        var when: String

        @Guide(description: "Geographic location name. Omit to use GPS.")
        var location: String?
    }

    // MARK: - JSON Schema (Must Match Arguments Struct)

    static let argumentsJSONSchema = """
        {
            "type": "object",
            "properties": {
                "when": {
                    "type": "string",
                    "enum": ["today", "tomorrow", "next_7_days"],
                    "description": "Time period for forecast"
                },
                "location": {
                    "type": "string",
                    "description": "Geographic location name. Omit to use GPS."
                }
            },
            "required": ["when"]
        }
        """

    // MARK: - Execution

    func execute(arguments: Arguments, context: SkillContext) async throws -> SkillResult {
        // Skill logic here - same regardless of which LLM provider was used
    }
}

// MARK: - Apple Tool (for Foundation Models)

#if canImport(FoundationModels)
@available(macOS 26.0, iOS 26.0, *)
extension WeatherForecastSkill {
    struct AppleTool: Tool {
        let name = WeatherForecastSkill.id
        let description = WeatherForecastSkill.description
        let recorder: ToolInvocationRecorder

        func call(arguments: Arguments) async throws -> String {
            await recorder.record(SkillCall(
                skillId: name,
                arguments: arguments.toDictionary()
            ))
            return "OK"
        }
    }
}
#endif
```

### SkillsRegistry

The registry becomes a simple collection of skill types:

```swift
struct SkillsRegistry {

    /// All skill types registered in the system.
    /// To add a new skill, add its type here.
    static let allSkillTypes: [any Skill.Type] = [
        WeatherForecastSkill.self,
        RemindersAddItemSkill.self,
        // Future: CalendarSkill.self, MessagesSkill.self, etc.
    ]

    var enabledSkillIds: Set<String>

    var enabledSkillTypes: [any Skill.Type] {
        Self.allSkillTypes.filter { enabledSkillIds.contains($0.id) }
    }

    func generateSkillsManifest() -> String {
        // Generates manifest from skill metadata for OpenAI providers
    }
}
```

### Execution Flow

Both providers produce an `LLMActionPlan`, but via different paths:

```
                        User Request
                             │
             ┌───────────────┴───────────────┐
             ▼                               ▼
   Apple Intelligence              OpenAI Compatible
             │                               │
   @Generable struct              JSON schema in prompt
   populated directly             Model returns JSON string
             │                               │
             ▼                               ▼
   LLMActionPlan.from(            LLMActionPlan.parse(
     toolInvocations:               from: jsonString
     [typed data]                 )
   )
             │                               │
             └───────────────┬───────────────┘
                             ▼
                      LLMActionPlan
                             │
                             ▼
                   AssistantCoordinator
                             │
                   skill.execute(arguments:context:)
                             │
                             ▼
                       SkillResult
```

Key points:
- Apple path: typed struct → `SkillCall` → `LLMActionPlan` (no JSON serialization)
- OpenAI path: JSON string → parse → `LLMActionPlan`
- Both converge at `LLMActionPlan`, then identical execution

### LLMActionPlan Changes

Add direct construction for Apple provider:

```swift
enum LLMActionPlan: Sendable {
    case respond(text: String)
    case callSkills(calls: [SkillCall])

    /// Parse from JSON string (OpenAI providers)
    static func parse(from jsonString: String) throws -> LLMActionPlan

    /// Construct directly from tool invocations (Apple provider)
    static func from(
        responseText: String,
        toolInvocations: [SkillCall]
    ) -> LLMActionPlan {
        if toolInvocations.isEmpty {
            return .respond(text: responseText)
        }
        return .callSkills(calls: toolInvocations)
    }
}
```

### AppleIntelligenceProvider Changes

Collect tools from skills rather than hardcoding:

```swift
#if canImport(FoundationModels)
@available(macOS 26.0, iOS 26.0, *)
extension AppleIntelligenceProvider {

    func makeTools(
        enabledSkills: [any Skill.Type],
        recorder: ToolInvocationRecorder
    ) -> [any Tool] {
        var tools: [any Tool] = []
        for skillType in enabledSkills {
            if let tool = makeToolForSkill(skillType, recorder: recorder) {
                tools.append(tool)
            }
        }
        return tools
    }

    private func makeToolForSkill(
        _ skillType: any Skill.Type,
        recorder: ToolInvocationRecorder
    ) -> (any Tool)? {
        // Switch needed because Swift can't dynamically instantiate associated types
        switch skillType {
        case is WeatherForecastSkill.Type:
            return WeatherForecastSkill.AppleTool(recorder: recorder)
        case is RemindersAddItemSkill.Type:
            return RemindersAddItemSkill.AppleTool(recorder: recorder)
        default:
            return nil
        }
    }
}
#endif
```

Note: When adding a new skill, add a case to this switch. This is documented in the skill-adding guide.

## Test Verification

Tests verify each skill's `Arguments` struct matches its `argumentsJSONSchema`:

```swift
struct SkillSchemaValidator {

    struct SchemaProperty {
        let name: String
        let type: String          // "string", "integer", "boolean", "array"
        let isRequired: Bool
        let enumValues: [String]?
    }

    /// Extract properties from a JSON schema string
    static func parseJSONSchema(_ schema: String) throws -> [SchemaProperty]

    /// Extract properties from a Codable struct using Mirror
    static func extractStructProperties<T: Codable>(_ type: T.Type) -> [SchemaProperty]

    /// Compare and report mismatches
    static func validate<S: Skill>(_ skill: S.Type) throws
}

// Per-skill tests
final class WeatherForecastSkillTests: XCTestCase {

    func testArgumentsMatchJSONSchema() throws {
        try SkillSchemaValidator.validate(WeatherForecastSkill.self)
    }

    func testJSONSchemaIsValidJSON() throws {
        let data = WeatherForecastSkill.argumentsJSONSchema.data(using: .utf8)!
        XCTAssertNoThrow(try JSONSerialization.jsonObject(with: data))
    }

    func testCanDecodeFromSchemaExample() throws {
        let json = """
            {"when": "today", "location": "London"}
            """
        let args = try JSONDecoder().decode(
            WeatherForecastSkill.Arguments.self,
            from: json.data(using: .utf8)!
        )
        XCTAssertEqual(args.when, "today")
    }
}
```

Tests verify:
1. Structural match (property names, types, required/optional)
2. JSON schema is valid JSON
3. Sample JSON decodes into the struct

## Files to Create/Modify

| File | Action |
|------|--------|
| `HeyLlama/Services/Skills/Skill.swift` | New - unified protocol |
| `HeyLlama/Services/Skills/SkillsRegistry.swift` | Modify - simplified registry |
| `HeyLlama/Services/Skills/WeatherForecastSkill.swift` | Modify - refactor to new pattern |
| `HeyLlama/Services/Skills/RemindersAddItemSkill.swift` | Modify - refactor to new pattern |
| `HeyLlama/Models/LLMActionPlan.swift` | Modify - add direct construction |
| `HeyLlama/Services/LLM/LLMProviders/AppleIntelligenceProvider.swift` | Modify - collect tools from skills |
| `HeyLlamaTests/SkillSchemaValidatorTests.swift` | New - validation utility and tests |
| `docs/adding-skills.md` | New - developer guide |

## Documentation Deliverables

1. **Inline code documentation**
   - Doc comments on all protocol properties
   - Warning comments on Arguments struct about JSON schema sync
   - Comments in registry explaining how to add skills

2. **Developer guide** (`docs/adding-skills.md`)
   - Step-by-step instructions for adding a new skill
   - Template code to copy
   - Common patterns (enums, optionals, arrays)
   - Troubleshooting section

3. **Template skill file**
   - Copy-paste starting point for new skills

## References

- [Apple Foundation Models framework](https://developer.apple.com/documentation/FoundationModels)
- [Meet the Foundation Models framework - WWDC25](https://developer.apple.com/videos/play/wwdc2025/286/)
- [Deep dive into the Foundation Models framework - WWDC25](https://developer.apple.com/videos/play/wwdc2025/301/)
- [Guided Generation with FoundationModels](https://medium.com/@luizfernandosalvaterra/guided-generation-with-foundationmodels-how-to-get-swift-structs-from-llms-ad663e60d716)
