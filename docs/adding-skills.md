# Adding a New Skill

This guide explains how to add a new skill to Hey Llama.

## Overview

Skills are voice-activated capabilities that the assistant can perform. Each skill:
- Is self-contained in a single file
- Works with both Apple Intelligence and OpenAI-compatible providers
- Defines its arguments once, with a matching JSON schema
- Has tests verifying the schema matches the struct

## Quick Start

1. Copy the template below to a new file in `HeyLlama/Services/Skills/`
2. Update the metadata, arguments, and execution logic
3. Add the skill type to `SkillsRegistry.allSkillTypes`
4. Add a case in `AppleIntelligenceProvider.makeToolForSkill()`
5. Write tests

## Template

```swift
import Foundation

// MARK: - Arguments

/// Arguments for the [skill name] skill.
///
/// IMPORTANT: When modifying this struct, you MUST update `argumentsJSONSchema`
/// to match. Run `[SkillName]SkillTests.testArgumentsMatchJSONSchema` to verify.
struct MyNewSkillArguments: Codable {
    /// Description of the required field
    let requiredField: String

    /// Description of the optional field
    let optionalField: String?
}

// MARK: - Skill Definition

struct MyNewSkill: Skill {

    // MARK: - Metadata

    static let id = "category.skill_name"
    static let name = "My New Skill"
    static let skillDescription = "Brief description for the LLM"
    static let requiredPermissions: [SkillPermission] = []
    static let includesInResponseAgent = true

    // MARK: - Arguments Type Alias

    typealias Arguments = MyNewSkillArguments

    // MARK: - JSON Schema

    static let argumentsJSONSchema = """
        {
            "type": "object",
            "properties": {
                "requiredField": {
                    "type": "string",
                    "description": "Description for LLM"
                },
                "optionalField": {
                    "type": "string",
                    "description": "Optional field description"
                }
            },
            "required": ["requiredField"]
        }
        """

    // MARK: - Execution

    func execute(arguments: Arguments, context: SkillContext) async throws -> SkillResult {
        // Your logic here
        return SkillResult(text: "Done")
    }

    // MARK: - Legacy API Support

    func run(argumentsJSON: String, context: SkillContext) async throws -> SkillResult {
        guard let data = argumentsJSON.data(using: .utf8) else {
            throw SkillError.invalidArguments("Invalid JSON encoding")
        }

        do {
            let args = try JSONDecoder().decode(Arguments.self, from: data)
            return try await execute(arguments: args, context: context)
        } catch let error as SkillError {
            throw error
        } catch {
            throw SkillError.invalidArguments("Failed to parse arguments: \(error.localizedDescription)")
        }
    }
}
```

## Registration Checklist

After creating your skill file:

### 1. Add to SkillsRegistry

In `HeyLlama/Services/Skills/SkillsRegistry.swift`:

```swift
static let allSkillTypes: [any Skill.Type] = [
    WeatherForecastSkill.self,
    RemindersAddItemSkill.self,
    MyNewSkill.self,  // Add here
]
```

Also add execution support in `executeSkill(skillId:argumentsJSON:context:)`:

```swift
case is MyNewSkill.Type:
    let args = try JSONDecoder().decode(
        MyNewSkillArguments.self,
        from: argumentsJSON.data(using: .utf8)!
    )
    return try await MyNewSkill().execute(arguments: args, context: context)
```

### 2. Add to AppleIntelligenceProvider

In `HeyLlama/Services/LLM/LLMProviders/AppleIntelligenceProvider.swift`:

First, add the tool struct (inside the `#if canImport(FoundationModels)` block):

```swift
@available(macOS 26.0, iOS 26.0, *)
struct MyNewSkillTool: Tool {
    let name: String = MyNewSkill.id
    let description: String = MyNewSkill.skillDescription
    let recorder: ToolInvocationRecorder

    @Generable
    struct Arguments: ConvertibleFromGeneratedContent {
        var requiredField: String
        var optionalField: String?
    }

    func call(arguments: Arguments) async throws -> String {
        var args: [String: Any] = ["requiredField": arguments.requiredField]
        if let opt = arguments.optionalField, !opt.isEmpty {
            args["optionalField"] = opt
        }
        await recorder.record(ToolInvocation(skillId: name, arguments: args))
        return "OK"
    }
}
```

Then add a case in `makeToolForSkill()`:

```swift
case is MyNewSkill.Type:
    return MyNewSkillTool(recorder: recorder)
```

### 3. Write Tests

Create `HeyLlamaTests/MyNewSkillTests.swift`:

```swift
import XCTest
@testable import HeyLlama

final class MyNewSkillTests: XCTestCase {

    // MARK: - Metadata Tests

    func testSkillHasCorrectId() {
        XCTAssertEqual(MyNewSkill.id, "category.skill_name")
    }

    func testSkillHasCorrectName() {
        XCTAssertEqual(MyNewSkill.name, "My New Skill")
    }

    // MARK: - Schema Validation Tests

    func testArgumentsJSONSchemaIsValidJSON() {
        let data = MyNewSkill.argumentsJSONSchema.data(using: .utf8)!
        XCTAssertNoThrow(try JSONSerialization.jsonObject(with: data))
    }

    func testArgumentsMatchJSONSchema() throws {
        try SkillSchemaValidator.validate(
            structType: MyNewSkillArguments.self,
            jsonSchema: MyNewSkill.argumentsJSONSchema
        )
    }

    // MARK: - Argument Decoding Tests

    func testCanDecodeArgumentsFromJSON() throws {
        let json = """
            {"requiredField": "test value"}
            """
        let data = json.data(using: .utf8)!
        let args = try JSONDecoder().decode(MyNewSkillArguments.self, from: data)

        XCTAssertEqual(args.requiredField, "test value")
        XCTAssertNil(args.optionalField)
    }
}
```

## Schema Sync Rules

The `Arguments` struct and `argumentsJSONSchema` MUST stay in sync:

| Swift | JSON Schema |
|-------|-------------|
| `let name: String` | `"name": {"type": "string"}` + in `required` array |
| `let count: Int` | `"count": {"type": "integer"}` + in `required` array |
| `let flag: Bool` | `"flag": {"type": "boolean"}` + in `required` array |
| `let items: [String]` | `"items": {"type": "array", "items": {"type": "string"}}` |
| `let name: String?` | `"name": {"type": "string"}` (NOT in `required`) |

Tests verify this automatically via `SkillSchemaValidator`.

## Permissions

If your skill needs system permissions, declare them:

```swift
static let requiredPermissions: [SkillPermission] = [.location, .reminders]
```

Available permissions:
- `.location` - GPS location (requires WeatherKit entitlement)
- `.reminders` - Apple Reminders (requires EventKit)

Future permissions (not yet implemented):
- `.calendar` - Apple Calendar
- `.contacts` - Contacts

## ResponseAgent Integration

Set `includesInResponseAgent = true` if your skill returns data that should be formatted conversationally by ResponseAgent. This is the common case.

Set `includesInResponseAgent = false` if your skill already returns user-ready text that should be displayed as-is.

## Common Patterns

### Enum Arguments

Use String in the struct, validate in `execute()`:

```swift
struct Arguments: Codable {
    let period: String  // Validated in execute()
}

static let argumentsJSONSchema = """
    {
        "type": "object",
        "properties": {
            "period": {
                "type": "string",
                "enum": ["daily", "weekly", "monthly"]
            }
        },
        "required": ["period"]
    }
    """
```

### Arrays

```swift
struct Arguments: Codable {
    let items: [String]
}

static let argumentsJSONSchema = """
    {
        "type": "object",
        "properties": {
            "items": {
                "type": "array",
                "items": {"type": "string"}
            }
        },
        "required": ["items"]
    }
    """
```

### Default Values

Use optional fields with `?` and handle defaults in `execute()`:

```swift
struct Arguments: Codable {
    let query: String
    let limit: Int?
}

func execute(arguments: Arguments, context: SkillContext) async throws -> SkillResult {
    let limit = arguments.limit ?? 10  // Default to 10
    // ...
}
```

## Troubleshooting

**Schema validation test fails**
- Check property names match exactly (case-sensitive)
- Check `required` array matches non-optional properties
- Check types match (String→string, Int→integer, Bool→boolean)

**Skill not appearing in LLM responses**
- Verify skill is in `SkillsRegistry.allSkillTypes`
- Verify skill ID is in enabled skills config
- Check LLM manifest includes the skill (`generateSkillsManifest()`)

**Apple Tool not working**
- Verify case exists in `makeToolForSkill()`
- Check `@Generable` macro is applied to Arguments in the Tool
- Verify macOS 26+ / iOS 26+
- Check Tool's Arguments struct matches skill's Arguments

**Permission errors**
- Verify permission is in `requiredPermissions`
- Check app has the required entitlements
- User must grant permission in System Settings

## Architecture Notes

The skill system supports two LLM providers:

1. **OpenAI-compatible** (Ollama, etc.): Uses `argumentsJSONSchema` in the skills manifest. LLM responds with JSON containing skill calls. `LLMActionPlan.parse()` extracts skill calls.

2. **Apple Intelligence**: Uses `@Generable` Tool structs with guided generation. Tool's `call()` method records invocations. `LLMActionPlan.from()` builds plan from recorded calls.

Both paths produce `LLMActionPlan.callSkills` which is executed identically by `AssistantCoordinator.executeSkillCalls()`.
