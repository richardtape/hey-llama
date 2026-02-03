# Skill Architecture Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Refactor the skill system so each skill is self-contained in a single file with both `@Generable` arguments and JSON schema, supporting Apple Intelligence and OpenAI providers.

**Architecture:** Skills conform to a `Skill` protocol with static metadata properties and an associated `Arguments` type. Apple provider collects Tool structs from skills; OpenAI provider uses JSON schemas from skills. Both produce `LLMActionPlan` which feeds into identical execution.

**Tech Stack:** Swift 5.9+, Foundation Models framework (`@Generable`, `Tool` protocol), JSON Schema

---

## Task 1: Create the Skill Protocol

Define the new unified protocol that all skills will conform to.

**Files:**
- Modify: `HeyLlama/Services/Skills/SkillProtocol.swift`

**Step 1: Write the failing test**

Add to `HeyLlamaTests/SkillProtocolTests.swift`:

```swift
import XCTest
@testable import HeyLlama

// Test that a mock skill can conform to the protocol
final class SkillProtocolConformanceTests: XCTestCase {

    struct MockSkill: Skill {
        static let id = "test.mock"
        static let name = "Mock Skill"
        static let skillDescription = "A mock skill for testing"
        static let requiredPermissions: [SkillPermission] = []
        static let includesInResponseAgent = true
        static let argumentsJSONSchema = """
            {"type": "object", "properties": {"input": {"type": "string"}}, "required": ["input"]}
            """

        struct Arguments: Codable, Sendable {
            let input: String
        }

        func execute(arguments: Arguments, context: SkillContext) async throws -> SkillResult {
            return SkillResult(text: "Received: \(arguments.input)")
        }
    }

    func testMockSkillConformsToProtocol() {
        XCTAssertEqual(MockSkill.id, "test.mock")
        XCTAssertEqual(MockSkill.name, "Mock Skill")
        XCTAssertEqual(MockSkill.skillDescription, "A mock skill for testing")
        XCTAssertEqual(MockSkill.requiredPermissions, [])
        XCTAssertTrue(MockSkill.includesInResponseAgent)
        XCTAssertFalse(MockSkill.argumentsJSONSchema.isEmpty)
    }

    func testMockSkillCanExecute() async throws {
        let skill = MockSkill()
        let args = MockSkill.Arguments(input: "hello")
        let context = SkillContext()

        let result = try await skill.execute(arguments: args, context: context)

        XCTAssertEqual(result.text, "Received: hello")
    }
}
```

**Step 2: Run test to verify it fails**

In Xcode: `Cmd+U` or run specific test via Test Navigator (`Cmd+6`)
Expected: FAIL - `Skill` protocol doesn't exist yet

**Step 3: Write the Skill protocol**

Replace contents of `HeyLlama/Services/Skills/SkillProtocol.swift`:

```swift
import Foundation

// MARK: - Skill Protocol

/// Protocol that all skills must conform to.
///
/// Each skill is completely self-contained in a single file with:
/// - Static metadata (id, name, description, permissions)
/// - An `Arguments` type marked `@Generable` for Apple's guided generation
/// - A JSON schema string for OpenAI-compatible providers
/// - Execution logic
///
/// ## Adding a New Skill
///
/// 1. Create a new file in `Services/Skills/` (e.g., `CalendarSkill.swift`)
/// 2. Define a struct conforming to `Skill`
/// 3. Define the `Arguments` struct with `@Generable` (if using Apple Intelligence)
/// 4. Write the matching `argumentsJSONSchema`
/// 5. Implement `execute(arguments:context:)`
/// 6. Add the skill type to `SkillsRegistry.allSkillTypes`
/// 7. Add tests verifying the JSON schema matches the Arguments struct
///
/// See `docs/adding-skills.md` for detailed instructions.
protocol Skill {
    /// Unique identifier (e.g., "weather.forecast")
    static var id: String { get }

    /// Human-readable name (e.g., "Weather Forecast")
    static var name: String { get }

    /// Description for LLM to understand when to use this skill.
    /// This is included in the skills manifest sent to the LLM.
    static var skillDescription: String { get }

    /// System permissions required to run this skill (e.g., [.location])
    static var requiredPermissions: [SkillPermission] { get }

    /// Whether ResponseAgent should synthesize a natural response from this skill's output.
    /// Set to `true` for skills that return data needing conversational formatting.
    /// Set to `false` for skills that already return user-ready text.
    static var includesInResponseAgent: Bool { get }

    /// JSON Schema describing the arguments for OpenAI-compatible providers.
    ///
    /// IMPORTANT: This schema MUST match the `Arguments` struct exactly.
    /// - Same property names
    /// - Same types (string, integer, boolean, array)
    /// - Same required/optional status
    ///
    /// Tests verify this stays in sync. See `SkillSchemaValidatorTests`.
    static var argumentsJSONSchema: String { get }

    /// The arguments type for this skill.
    /// For Apple Intelligence, mark this with `@Generable` in your skill file.
    associatedtype Arguments: Codable, Sendable

    /// Execute the skill with parsed arguments.
    ///
    /// - Parameters:
    ///   - arguments: Decoded arguments (either from Apple's guided generation or JSON)
    ///   - context: Execution context including speaker info and timestamp
    /// - Returns: Skill result with text response and optional structured data
    func execute(arguments: Arguments, context: SkillContext) async throws -> SkillResult
}

// MARK: - Supporting Types

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
struct SkillResult {
    let text: String
    let data: [String: Any]?
    let summary: SkillSummary?

    init(text: String, data: [String: Any]? = nil, summary: SkillSummary? = nil) {
        self.text = text
        self.data = data
        self.summary = summary
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
```

**Step 4: Run test to verify it passes**

In Xcode: `Cmd+U`
Expected: PASS

**Step 5: Commit**

```bash
git add HeyLlama/Services/Skills/SkillProtocol.swift HeyLlamaTests/SkillProtocolTests.swift
git commit -m "feat(skills): add unified Skill protocol

Defines protocol with static metadata, associated Arguments type,
and execute method. Each skill will be self-contained with both
@Generable struct and JSON schema."
```

---

## Task 2: Create Schema Validation Test Utilities

Build test infrastructure to verify Swift structs match JSON schemas.

**Files:**
- Create: `HeyLlamaTests/SkillSchemaValidator.swift`
- Create: `HeyLlamaTests/SkillSchemaValidatorTests.swift`

**Step 1: Write the failing test**

Create `HeyLlamaTests/SkillSchemaValidatorTests.swift`:

```swift
import XCTest
@testable import HeyLlama

final class SkillSchemaValidatorTests: XCTestCase {

    // MARK: - JSON Schema Parsing Tests

    func testParseSimpleSchema() throws {
        let schema = """
            {
                "type": "object",
                "properties": {
                    "name": {"type": "string"},
                    "count": {"type": "integer"}
                },
                "required": ["name"]
            }
            """

        let properties = try SkillSchemaValidator.parseJSONSchema(schema)

        XCTAssertEqual(properties.count, 2)

        let nameProperty = properties.first { $0.name == "name" }
        XCTAssertNotNil(nameProperty)
        XCTAssertEqual(nameProperty?.type, "string")
        XCTAssertTrue(nameProperty?.isRequired ?? false)

        let countProperty = properties.first { $0.name == "count" }
        XCTAssertNotNil(countProperty)
        XCTAssertEqual(countProperty?.type, "integer")
        XCTAssertFalse(countProperty?.isRequired ?? true)
    }

    func testParseSchemaWithEnum() throws {
        let schema = """
            {
                "type": "object",
                "properties": {
                    "status": {
                        "type": "string",
                        "enum": ["pending", "active", "done"]
                    }
                },
                "required": ["status"]
            }
            """

        let properties = try SkillSchemaValidator.parseJSONSchema(schema)

        let statusProperty = properties.first { $0.name == "status" }
        XCTAssertNotNil(statusProperty)
        XCTAssertEqual(statusProperty?.enumValues, ["pending", "active", "done"])
    }

    // MARK: - Struct Extraction Tests

    func testExtractPropertiesFromCodableStruct() throws {
        struct TestArgs: Codable {
            let name: String
            let count: Int?
        }

        let properties = try SkillSchemaValidator.extractStructProperties(TestArgs.self)

        XCTAssertEqual(properties.count, 2)

        let nameProperty = properties.first { $0.name == "name" }
        XCTAssertNotNil(nameProperty)
        XCTAssertEqual(nameProperty?.type, "string")
        XCTAssertTrue(nameProperty?.isRequired ?? false)

        let countProperty = properties.first { $0.name == "count" }
        XCTAssertNotNil(countProperty)
        XCTAssertEqual(countProperty?.type, "integer")
        XCTAssertFalse(countProperty?.isRequired ?? true)
    }

    // MARK: - Validation Tests

    func testValidateMatchingSchemaAndStruct() throws {
        struct MatchingArgs: Codable {
            let name: String
            let count: Int?
        }

        let schema = """
            {
                "type": "object",
                "properties": {
                    "name": {"type": "string"},
                    "count": {"type": "integer"}
                },
                "required": ["name"]
            }
            """

        // Should not throw
        XCTAssertNoThrow(try SkillSchemaValidator.validate(
            structType: MatchingArgs.self,
            jsonSchema: schema
        ))
    }

    func testValidateMismatchedPropertyNames() throws {
        struct MismatchedArgs: Codable {
            let title: String  // Schema has "name"
        }

        let schema = """
            {
                "type": "object",
                "properties": {
                    "name": {"type": "string"}
                },
                "required": ["name"]
            }
            """

        XCTAssertThrowsError(try SkillSchemaValidator.validate(
            structType: MismatchedArgs.self,
            jsonSchema: schema
        )) { error in
            let message = "\(error)"
            XCTAssertTrue(message.contains("name") || message.contains("title"))
        }
    }

    func testValidateMismatchedRequiredStatus() throws {
        struct MismatchedArgs: Codable {
            let name: String?  // Schema has it as required
        }

        let schema = """
            {
                "type": "object",
                "properties": {
                    "name": {"type": "string"}
                },
                "required": ["name"]
            }
            """

        XCTAssertThrowsError(try SkillSchemaValidator.validate(
            structType: MismatchedArgs.self,
            jsonSchema: schema
        )) { error in
            let message = "\(error)"
            XCTAssertTrue(message.contains("required") || message.contains("optional"))
        }
    }
}
```

**Step 2: Run test to verify it fails**

In Xcode: `Cmd+U`
Expected: FAIL - `SkillSchemaValidator` doesn't exist

**Step 3: Implement SkillSchemaValidator**

Create `HeyLlamaTests/SkillSchemaValidator.swift`:

```swift
import Foundation

/// Utility to validate that a Skill's Arguments struct matches its JSON schema.
///
/// Used in tests to ensure Swift types and JSON schemas stay in sync.
/// See `docs/adding-skills.md` for details on schema requirements.
enum SkillSchemaValidator {

    /// Represents a property extracted from either a JSON schema or Swift struct
    struct SchemaProperty: Equatable {
        let name: String
        let type: String          // "string", "integer", "number", "boolean", "array"
        let isRequired: Bool
        let enumValues: [String]?

        init(name: String, type: String, isRequired: Bool, enumValues: [String]? = nil) {
            self.name = name
            self.type = type
            self.isRequired = isRequired
            self.enumValues = enumValues
        }
    }

    /// Errors that can occur during validation
    enum ValidationError: Error, LocalizedError {
        case invalidJSONSchema(String)
        case propertyMissing(schemaHas: String?, structHas: String?)
        case typeMismatch(property: String, schemaType: String, structType: String)
        case requiredMismatch(property: String, schemaRequired: Bool, structRequired: Bool)

        var errorDescription: String? {
            switch self {
            case .invalidJSONSchema(let message):
                return "Invalid JSON schema: \(message)"
            case .propertyMissing(let schemaHas, let structHas):
                if let schemaName = schemaHas {
                    return "Schema has property '\(schemaName)' but struct does not"
                } else if let structName = structHas {
                    return "Struct has property '\(structName)' but schema does not"
                }
                return "Property mismatch between schema and struct"
            case .typeMismatch(let property, let schemaType, let structType):
                return "Type mismatch for '\(property)': schema has '\(schemaType)', struct has '\(structType)'"
            case .requiredMismatch(let property, let schemaRequired, let structRequired):
                let schemaStatus = schemaRequired ? "required" : "optional"
                let structStatus = structRequired ? "required" : "optional"
                return "Required mismatch for '\(property)': schema is \(schemaStatus), struct is \(structStatus)"
            }
        }
    }

    // MARK: - JSON Schema Parsing

    /// Parse a JSON schema string into a list of properties
    static func parseJSONSchema(_ schema: String) throws -> [SchemaProperty] {
        guard let data = schema.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ValidationError.invalidJSONSchema("Failed to parse JSON")
        }

        guard let properties = json["properties"] as? [String: Any] else {
            throw ValidationError.invalidJSONSchema("Missing 'properties' field")
        }

        let required = json["required"] as? [String] ?? []

        var result: [SchemaProperty] = []

        for (name, value) in properties {
            guard let propertyDict = value as? [String: Any] else {
                continue
            }

            let type = propertyDict["type"] as? String ?? "string"
            let isRequired = required.contains(name)
            let enumValues = propertyDict["enum"] as? [String]

            result.append(SchemaProperty(
                name: name,
                type: type,
                isRequired: isRequired,
                enumValues: enumValues
            ))
        }

        return result.sorted { $0.name < $1.name }
    }

    // MARK: - Struct Property Extraction

    /// Extract properties from a Codable struct using Mirror
    static func extractStructProperties<T: Codable>(_ type: T.Type) throws -> [SchemaProperty] {
        // Create a dummy instance to inspect with Mirror
        // We use a decoder that provides default values
        let decoder = DummyDecoder()

        // Try to decode - this will fail but we can inspect the keys
        do {
            _ = try T(from: decoder)
        } catch {
            // Expected - we're using a dummy decoder
        }

        return decoder.capturedProperties.sorted { $0.name < $1.name }
    }

    // MARK: - Validation

    /// Validate that a struct type matches a JSON schema
    static func validate<T: Codable>(
        structType: T.Type,
        jsonSchema: String
    ) throws {
        let schemaProperties = try parseJSONSchema(jsonSchema)
        let structProperties = try extractStructProperties(structType)

        // Check for missing properties
        let schemaNames = Set(schemaProperties.map { $0.name })
        let structNames = Set(structProperties.map { $0.name })

        for name in schemaNames.subtracting(structNames) {
            throw ValidationError.propertyMissing(schemaHas: name, structHas: nil)
        }

        for name in structNames.subtracting(schemaNames) {
            throw ValidationError.propertyMissing(schemaHas: nil, structHas: name)
        }

        // Check matching properties
        for schemaProp in schemaProperties {
            guard let structProp = structProperties.first(where: { $0.name == schemaProp.name }) else {
                continue // Already handled above
            }

            // Check types match
            if schemaProp.type != structProp.type {
                throw ValidationError.typeMismatch(
                    property: schemaProp.name,
                    schemaType: schemaProp.type,
                    structType: structProp.type
                )
            }

            // Check required status matches
            if schemaProp.isRequired != structProp.isRequired {
                throw ValidationError.requiredMismatch(
                    property: schemaProp.name,
                    schemaRequired: schemaProp.isRequired,
                    structRequired: structProp.isRequired
                )
            }
        }
    }
}

// MARK: - Dummy Decoder for Property Extraction

/// A decoder that captures property names and types without actually decoding
private class DummyDecoder: Decoder {
    var codingPath: [CodingKey] = []
    var userInfo: [CodingUserInfoKey: Any] = [:]
    var capturedProperties: [SkillSchemaValidator.SchemaProperty] = []

    func container<Key: CodingKey>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> {
        return KeyedDecodingContainer(DummyKeyedContainer<Key>(decoder: self))
    }

    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        fatalError("Not implemented")
    }

    func singleValueContainer() throws -> SingleValueDecodingContainer {
        fatalError("Not implemented")
    }
}

private struct DummyKeyedContainer<K: CodingKey>: KeyedDecodingContainerProtocol {
    typealias Key = K

    var codingPath: [CodingKey] = []
    var allKeys: [K] = []
    let decoder: DummyDecoder

    init(decoder: DummyDecoder) {
        self.decoder = decoder
    }

    func contains(_ key: K) -> Bool { true }

    func decodeNil(forKey key: K) throws -> Bool {
        // Returning true means "this is optional and nil"
        return true
    }

    func decode(_ type: Bool.Type, forKey key: K) throws -> Bool {
        decoder.capturedProperties.append(SkillSchemaValidator.SchemaProperty(
            name: key.stringValue,
            type: "boolean",
            isRequired: true
        ))
        throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Dummy"))
    }

    func decode(_ type: String.Type, forKey key: K) throws -> String {
        decoder.capturedProperties.append(SkillSchemaValidator.SchemaProperty(
            name: key.stringValue,
            type: "string",
            isRequired: true
        ))
        throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Dummy"))
    }

    func decode(_ type: Double.Type, forKey key: K) throws -> Double {
        decoder.capturedProperties.append(SkillSchemaValidator.SchemaProperty(
            name: key.stringValue,
            type: "number",
            isRequired: true
        ))
        throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Dummy"))
    }

    func decode(_ type: Float.Type, forKey key: K) throws -> Float {
        decoder.capturedProperties.append(SkillSchemaValidator.SchemaProperty(
            name: key.stringValue,
            type: "number",
            isRequired: true
        ))
        throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Dummy"))
    }

    func decode(_ type: Int.Type, forKey key: K) throws -> Int {
        decoder.capturedProperties.append(SkillSchemaValidator.SchemaProperty(
            name: key.stringValue,
            type: "integer",
            isRequired: true
        ))
        throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Dummy"))
    }

    func decode<T: Decodable>(_ type: T.Type, forKey key: K) throws -> T {
        let typeName = mapSwiftTypeToJSONType(type)
        decoder.capturedProperties.append(SkillSchemaValidator.SchemaProperty(
            name: key.stringValue,
            type: typeName,
            isRequired: true
        ))
        throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Dummy"))
    }

    func decodeIfPresent(_ type: Bool.Type, forKey key: K) throws -> Bool? {
        decoder.capturedProperties.append(SkillSchemaValidator.SchemaProperty(
            name: key.stringValue,
            type: "boolean",
            isRequired: false
        ))
        return nil
    }

    func decodeIfPresent(_ type: String.Type, forKey key: K) throws -> String? {
        decoder.capturedProperties.append(SkillSchemaValidator.SchemaProperty(
            name: key.stringValue,
            type: "string",
            isRequired: false
        ))
        return nil
    }

    func decodeIfPresent(_ type: Double.Type, forKey key: K) throws -> Double? {
        decoder.capturedProperties.append(SkillSchemaValidator.SchemaProperty(
            name: key.stringValue,
            type: "number",
            isRequired: false
        ))
        return nil
    }

    func decodeIfPresent(_ type: Float.Type, forKey key: K) throws -> Float? {
        decoder.capturedProperties.append(SkillSchemaValidator.SchemaProperty(
            name: key.stringValue,
            type: "number",
            isRequired: false
        ))
        return nil
    }

    func decodeIfPresent(_ type: Int.Type, forKey key: K) throws -> Int? {
        decoder.capturedProperties.append(SkillSchemaValidator.SchemaProperty(
            name: key.stringValue,
            type: "integer",
            isRequired: false
        ))
        return nil
    }

    func decodeIfPresent<T: Decodable>(_ type: T.Type, forKey key: K) throws -> T? {
        let typeName = mapSwiftTypeToJSONType(type)
        decoder.capturedProperties.append(SkillSchemaValidator.SchemaProperty(
            name: key.stringValue,
            type: typeName,
            isRequired: false
        ))
        return nil
    }

    func nestedContainer<NestedKey: CodingKey>(keyedBy type: NestedKey.Type, forKey key: K) throws -> KeyedDecodingContainer<NestedKey> {
        fatalError("Not implemented")
    }

    func nestedUnkeyedContainer(forKey key: K) throws -> UnkeyedDecodingContainer {
        fatalError("Not implemented")
    }

    func superDecoder() throws -> Decoder {
        fatalError("Not implemented")
    }

    func superDecoder(forKey key: K) throws -> Decoder {
        fatalError("Not implemented")
    }

    private func mapSwiftTypeToJSONType<T>(_ type: T.Type) -> String {
        let typeName = String(describing: type)
        switch typeName {
        case "String": return "string"
        case "Int", "Int8", "Int16", "Int32", "Int64": return "integer"
        case "Double", "Float": return "number"
        case "Bool": return "boolean"
        default:
            if typeName.hasPrefix("Array") {
                return "array"
            }
            return "string" // Default to string for unknown types
        }
    }
}
```

**Step 4: Run test to verify it passes**

In Xcode: `Cmd+U`
Expected: PASS

**Step 5: Commit**

```bash
git add HeyLlamaTests/SkillSchemaValidator.swift HeyLlamaTests/SkillSchemaValidatorTests.swift
git commit -m "test(skills): add schema validation test utilities

SkillSchemaValidator verifies that a Skill's Arguments struct
matches its JSON schema. Checks property names, types, and
required/optional status."
```

---

## Task 3: Refactor WeatherForecastSkill to New Pattern

Convert the first skill to the new self-contained pattern.

**Files:**
- Modify: `HeyLlama/Services/Skills/WeatherForecastSkill.swift`
- Modify: `HeyLlamaTests/WeatherForecastSkillTests.swift`

**Step 1: Write schema validation test**

Add to `HeyLlamaTests/WeatherForecastSkillTests.swift`:

```swift
func testArgumentsMatchJSONSchema() throws {
    try SkillSchemaValidator.validate(
        structType: WeatherForecastSkill.Arguments.self,
        jsonSchema: WeatherForecastSkill.argumentsJSONSchema
    )
}

func testCanDecodeArgumentsFromJSON() throws {
    let json = """
        {"when": "today", "location": "London"}
        """
    let data = json.data(using: .utf8)!
    let args = try JSONDecoder().decode(WeatherForecastSkill.Arguments.self, from: data)

    XCTAssertEqual(args.when, "today")
    XCTAssertEqual(args.location, "London")
}

func testCanDecodeArgumentsWithoutOptionalFields() throws {
    let json = """
        {"when": "tomorrow"}
        """
    let data = json.data(using: .utf8)!
    let args = try JSONDecoder().decode(WeatherForecastSkill.Arguments.self, from: data)

    XCTAssertEqual(args.when, "tomorrow")
    XCTAssertNil(args.location)
}
```

**Step 2: Run test to verify it fails**

In Xcode: `Cmd+U`
Expected: FAIL - `WeatherForecastSkill` doesn't conform to new `Skill` protocol yet

**Step 3: Refactor WeatherForecastSkill**

Replace contents of `HeyLlama/Services/Skills/WeatherForecastSkill.swift`:

```swift
import Foundation
import WeatherKit
import CoreLocation
#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Skill Definition

/// Weather forecast skill using WeatherKit.
///
/// Provides current conditions and forecasts for today, tomorrow, or 7 days.
/// Uses GPS location by default, or a specified location name.
struct WeatherForecastSkill: Skill {

    // MARK: - Skill Metadata

    static let id = "weather.forecast"
    static let name = "Weather Forecast"
    static let skillDescription = "Get the weather forecast for today, tomorrow, or the next 7 days"
    static let requiredPermissions: [SkillPermission] = [.location]
    static let includesInResponseAgent = true

    // MARK: - Arguments

    /// Arguments for the weather forecast skill.
    ///
    /// IMPORTANT: When modifying this struct, you MUST update `argumentsJSONSchema`
    /// to match. Run `WeatherForecastSkillTests.testArgumentsMatchJSONSchema` to verify.
    ///
    /// For Apple Intelligence, this struct should be marked with `@Generable` in the
    /// `#if canImport(FoundationModels)` block below.
    struct Arguments: Codable, Sendable {
        /// Time period for the forecast: "today", "tomorrow", or "next_7_days"
        let when: String

        /// Geographic location name (city, region, address).
        /// Omit to use the user's GPS location.
        let location: String?
    }

    // MARK: - JSON Schema

    /// JSON Schema for OpenAI-compatible providers.
    ///
    /// IMPORTANT: This schema MUST match the `Arguments` struct above.
    /// - Property names must be identical
    /// - Types must match (String -> "string", Int -> "integer", etc.)
    /// - Required fields must be non-optional in the struct
    /// - Optional fields must be optional (?) in the struct
    static let argumentsJSONSchema = """
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
                    "description": "A geographic place name (city, region, or address). Omit to use GPS location."
                }
            },
            "required": ["when"]
        }
        """

    // MARK: - Execution

    func execute(arguments: Arguments, context: SkillContext) async throws -> SkillResult {
        // Parse the time period
        let period = parseTimePeriod(arguments.when)

        // Normalize location, filtering out speaker name if LLM incorrectly passed it
        let normalizedLocation = LocationHelpers.normalizeLocationToken(
            arguments.location,
            speakerName: context.speaker?.name
        )

        // Get location
        let location: CLLocation
        if let locationName = normalizedLocation {
            location = try await LocationHelpers.geocodeLocation(locationName)
        } else {
            location = try await LocationHelpers.getCurrentLocation()
        }

        // Fetch weather
        let weatherService = WeatherService.shared
        let weather = try await weatherService.weather(for: location)

        // Format response
        let responseText = formatWeatherResponse(
            weather: weather,
            period: period,
            locationName: normalizedLocation
        )

        let summary = SkillSummary(
            skillId: Self.id,
            status: .success,
            summary: responseText,
            details: [
                "temperature": weather.currentWeather.temperature.value,
                "temperatureUnit": weather.currentWeather.temperature.unit.symbol,
                "condition": weather.currentWeather.condition.description
            ]
        )

        return SkillResult(text: responseText, data: [
            "temperature": weather.currentWeather.temperature.value,
            "temperatureUnit": weather.currentWeather.temperature.unit.symbol,
            "condition": weather.currentWeather.condition.description
        ], summary: summary)
    }

    // MARK: - Private Helpers

    private enum TimePeriod {
        case today
        case tomorrow
        case next7Days
    }

    private func parseTimePeriod(_ value: String) -> TimePeriod {
        switch value.lowercased() {
        case "tomorrow": return .tomorrow
        case "next_7_days", "next7days", "week": return .next7Days
        default: return .today
        }
    }

    private func formatTemperature(_ measurement: Measurement<UnitTemperature>) -> String {
        let value = measurement.value
        let rounded = (value * 2).rounded() / 2
        let unit = measurement.unit.symbol
        if rounded == rounded.rounded() {
            return "\(Int(rounded))\(unit)"
        } else {
            return String(format: "%.1f%@", rounded, unit)
        }
    }

    private func formatWeatherResponse(
        weather: Weather,
        period: TimePeriod,
        locationName: String?
    ) -> String {
        let locationStr = locationName ?? "your location"
        let current = weather.currentWeather

        switch period {
        case .today:
            let temp = formatTemperature(current.temperature)
            let condition = current.condition.description
            let high = weather.dailyForecast.first.map { formatTemperature($0.highTemperature) } ?? "N/A"
            let low = weather.dailyForecast.first.map { formatTemperature($0.lowTemperature) } ?? "N/A"
            return "The weather in \(locationStr) today is \(condition) with a current temperature of \(temp). Expected high of \(high) and low of \(low)."

        case .tomorrow:
            guard weather.dailyForecast.count > 1 else {
                return "Tomorrow's forecast is not available."
            }
            let tomorrow = weather.dailyForecast[1]
            let condition = tomorrow.condition.description
            let high = formatTemperature(tomorrow.highTemperature)
            let low = formatTemperature(tomorrow.lowTemperature)
            return "Tomorrow in \(locationStr) will be \(condition) with a high of \(high) and low of \(low)."

        case .next7Days:
            var forecast = "Here's the 7-day forecast for \(locationStr):\n"
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "EEEE"

            for (index, day) in weather.dailyForecast.prefix(7).enumerated() {
                let dayName = index == 0 ? "Today" : dateFormatter.string(from: day.date)
                let condition = day.condition.description
                let high = formatTemperature(day.highTemperature)
                let low = formatTemperature(day.lowTemperature)
                forecast += "- \(dayName): \(condition), \(high)/\(low)\n"
            }
            return forecast
        }
    }
}

// MARK: - Apple Tool (for Foundation Models)

#if canImport(FoundationModels)
@available(macOS 26.0, iOS 26.0, *)
extension WeatherForecastSkill {

    /// Tool for Apple's Foundation Models framework.
    ///
    /// This wraps the skill for use with `LanguageModelSession`.
    /// The `@Generable` Arguments struct enables guided generation.
    struct AppleTool: Tool {
        let name = WeatherForecastSkill.id
        let description = WeatherForecastSkill.skillDescription
        let recorder: ToolInvocationRecorder

        /// Arguments with guided generation support.
        @Generable
        struct Arguments: Sendable {
            @Guide(description: "Time period: today, tomorrow, or next_7_days")
            var when: String

            @Guide(description: "Location name. Omit for GPS.")
            var location: String?
        }

        func call(arguments: Arguments) async throws -> String {
            var args: [String: Any] = ["when": arguments.when]
            if let location = arguments.location, !location.isEmpty {
                args["location"] = location
            }
            await recorder.record(SkillCall(skillId: name, arguments: args))
            return "OK"
        }
    }
}
#endif
```

**Step 4: Update tests to use new API**

Update `HeyLlamaTests/WeatherForecastSkillTests.swift` - replace old tests that used `RegisteredSkill`:

```swift
import XCTest
@testable import HeyLlama

final class WeatherForecastSkillTests: XCTestCase {

    // MARK: - Metadata Tests

    func testSkillHasCorrectId() {
        XCTAssertEqual(WeatherForecastSkill.id, "weather.forecast")
    }

    func testSkillHasCorrectName() {
        XCTAssertEqual(WeatherForecastSkill.name, "Weather Forecast")
    }

    func testSkillRequiresLocationPermission() {
        XCTAssertTrue(WeatherForecastSkill.requiredPermissions.contains(.location))
    }

    func testSkillIncludesInResponseAgent() {
        XCTAssertTrue(WeatherForecastSkill.includesInResponseAgent)
    }

    // MARK: - Schema Validation Tests

    func testArgumentsJSONSchemaIsValidJSON() {
        let data = WeatherForecastSkill.argumentsJSONSchema.data(using: .utf8)!
        XCTAssertNoThrow(try JSONSerialization.jsonObject(with: data))
    }

    func testArgumentsMatchJSONSchema() throws {
        try SkillSchemaValidator.validate(
            structType: WeatherForecastSkill.Arguments.self,
            jsonSchema: WeatherForecastSkill.argumentsJSONSchema
        )
    }

    // MARK: - Argument Decoding Tests

    func testCanDecodeArgumentsFromJSON() throws {
        let json = """
            {"when": "today", "location": "San Francisco"}
            """
        let data = json.data(using: .utf8)!
        let args = try JSONDecoder().decode(WeatherForecastSkill.Arguments.self, from: data)

        XCTAssertEqual(args.when, "today")
        XCTAssertEqual(args.location, "San Francisco")
    }

    func testCanDecodeArgumentsWithoutLocation() throws {
        let json = """
            {"when": "tomorrow"}
            """
        let data = json.data(using: .utf8)!
        let args = try JSONDecoder().decode(WeatherForecastSkill.Arguments.self, from: data)

        XCTAssertEqual(args.when, "tomorrow")
        XCTAssertNil(args.location)
    }

    func testCanDecodeNext7DaysArguments() throws {
        let json = """
            {"when": "next_7_days"}
            """
        let data = json.data(using: .utf8)!
        let args = try JSONDecoder().decode(WeatherForecastSkill.Arguments.self, from: data)

        XCTAssertEqual(args.when, "next_7_days")
    }

    // MARK: - Location Normalization Tests

    func testNormalizeLocationTokenReturnsNilForUserLocation() {
        XCTAssertNil(LocationHelpers.normalizeLocationToken("user"))
    }
}
```

**Step 5: Run tests to verify they pass**

In Xcode: `Cmd+U`
Expected: PASS

**Step 6: Commit**

```bash
git add HeyLlama/Services/Skills/WeatherForecastSkill.swift HeyLlamaTests/WeatherForecastSkillTests.swift
git commit -m "refactor(skills): convert WeatherForecastSkill to new pattern

WeatherForecastSkill now conforms to Skill protocol with:
- Static metadata properties
- Arguments struct (Codable, Sendable)
- Co-located JSON schema
- Apple Tool in #if canImport block
- execute(arguments:context:) method

Tests verify schema matches struct."
```

---

## Task 4: Refactor RemindersAddItemSkill to New Pattern

Convert the second skill to the new pattern.

**Files:**
- Modify: `HeyLlama/Services/Skills/RemindersAddItemSkill.swift`
- Modify: `HeyLlamaTests/RemindersAddItemSkillTests.swift`

**Step 1: Write schema validation test**

Add to `HeyLlamaTests/RemindersAddItemSkillTests.swift`:

```swift
func testArgumentsMatchJSONSchema() throws {
    try SkillSchemaValidator.validate(
        structType: RemindersAddItemSkill.Arguments.self,
        jsonSchema: RemindersAddItemSkill.argumentsJSONSchema
    )
}

func testArgumentsJSONSchemaIsValidJSON() {
    let data = RemindersAddItemSkill.argumentsJSONSchema.data(using: .utf8)!
    XCTAssertNoThrow(try JSONSerialization.jsonObject(with: data))
}
```

**Step 2: Run test to verify it fails**

In Xcode: `Cmd+U`
Expected: FAIL - `RemindersAddItemSkill` doesn't have `argumentsJSONSchema` yet

**Step 3: Refactor RemindersAddItemSkill**

Replace contents of `HeyLlama/Services/Skills/RemindersAddItemSkill.swift`:

```swift
import Foundation
import EventKit
#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Skill Definition

/// Skill to add items to Apple Reminders lists.
struct RemindersAddItemSkill: Skill {

    // MARK: - Skill Metadata

    static let id = "reminders.add_item"
    static let name = "Add Reminder"
    static let skillDescription = "Add an item to a Reminders list (e.g., 'add milk to the groceries list')"
    static let requiredPermissions: [SkillPermission] = [.reminders]
    static let includesInResponseAgent = true

    // MARK: - Arguments

    /// Arguments for the reminders skill.
    ///
    /// IMPORTANT: When modifying this struct, you MUST update `argumentsJSONSchema`
    /// to match. Run `RemindersAddItemSkillTests.testArgumentsMatchJSONSchema` to verify.
    struct Arguments: Codable, Sendable {
        /// The name of the Reminders list to add to
        let listName: String

        /// The item/reminder to add
        let itemName: String

        /// Optional notes for the reminder
        let notes: String?

        /// Optional due date in ISO8601 format
        let dueDateISO8601: String?
    }

    // MARK: - JSON Schema

    /// JSON Schema for OpenAI-compatible providers.
    ///
    /// IMPORTANT: This schema MUST match the `Arguments` struct above.
    static let argumentsJSONSchema = """
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

    // MARK: - Execution

    func execute(arguments: Arguments, context: SkillContext) async throws -> SkillResult {
        // Check permission
        var status = Permissions.checkRemindersStatus()
        if status == .undetermined {
            let granted = await Permissions.requestRemindersAccess()
            status = granted ? .granted : .denied
        }
        guard status == .granted else {
            throw SkillError.permissionDenied(.reminders)
        }

        let eventStore = EKEventStore()

        // Find the target list
        let targetCalendar = try RemindersHelpers.findReminderList(
            named: arguments.listName,
            in: eventStore
        )

        // Create the reminder
        let reminder = EKReminder(eventStore: eventStore)
        reminder.title = arguments.itemName
        reminder.calendar = targetCalendar

        if let notes = arguments.notes {
            reminder.notes = notes
        }

        if let dueDateString = arguments.dueDateISO8601 {
            reminder.dueDateComponents = RemindersHelpers.parseDueDateISO8601(dueDateString)
        }

        // Save the reminder
        do {
            try eventStore.save(reminder, commit: true)
        } catch {
            throw SkillError.executionFailed("Failed to save reminder: \(error.localizedDescription)")
        }

        // Build response
        var response = "Added '\(arguments.itemName)' to your \(targetCalendar.title) list"
        if arguments.notes != nil {
            response += " with notes"
        }
        if arguments.dueDateISO8601 != nil {
            response += " with a due date"
        }
        response += "."

        let summary = SkillSummary(
            skillId: Self.id,
            status: .success,
            summary: response,
            details: [
                "listName": targetCalendar.title,
                "itemName": arguments.itemName,
                "reminderId": reminder.calendarItemIdentifier
            ]
        )

        return SkillResult(
            text: response,
            data: [
                "listName": targetCalendar.title,
                "itemName": arguments.itemName,
                "reminderId": reminder.calendarItemIdentifier
            ],
            summary: summary
        )
    }
}

// MARK: - Apple Tool (for Foundation Models)

#if canImport(FoundationModels)
@available(macOS 26.0, iOS 26.0, *)
extension RemindersAddItemSkill {

    /// Tool for Apple's Foundation Models framework.
    struct AppleTool: Tool {
        let name = RemindersAddItemSkill.id
        let description = RemindersAddItemSkill.skillDescription
        let recorder: ToolInvocationRecorder

        @Generable
        struct Arguments: Sendable {
            @Guide(description: "Name of the Reminders list")
            var listName: String

            @Guide(description: "The item to add")
            var itemName: String

            @Guide(description: "Optional notes")
            var notes: String?

            @Guide(description: "Due date in ISO8601 format")
            var dueDateISO8601: String?
        }

        func call(arguments: Arguments) async throws -> String {
            var args: [String: Any] = [
                "listName": arguments.listName,
                "itemName": arguments.itemName
            ]
            if let notes = arguments.notes, !notes.isEmpty {
                args["notes"] = notes
            }
            if let dueDate = arguments.dueDateISO8601, !dueDate.isEmpty {
                args["dueDateISO8601"] = dueDate
            }
            await recorder.record(SkillCall(skillId: name, arguments: args))
            return "OK"
        }
    }
}
#endif
```

**Step 4: Update tests**

Update `HeyLlamaTests/RemindersAddItemSkillTests.swift` to use new API.

**Step 5: Run tests**

In Xcode: `Cmd+U`
Expected: PASS

**Step 6: Commit**

```bash
git add HeyLlama/Services/Skills/RemindersAddItemSkill.swift HeyLlamaTests/RemindersAddItemSkillTests.swift
git commit -m "refactor(skills): convert RemindersAddItemSkill to new pattern

RemindersAddItemSkill now conforms to Skill protocol with
co-located Arguments struct, JSON schema, and Apple Tool."
```

---

## Task 5: Update SkillsRegistry to Use Skill Types

Replace the enum-based registry with a type-based collection.

**Files:**
- Modify: `HeyLlama/Services/Skills/SkillsRegistry.swift`
- Modify: `HeyLlamaTests/SkillsRegistryTests.swift`

**Step 1: Write failing tests for new API**

Update `HeyLlamaTests/SkillsRegistryTests.swift`:

```swift
func testRegistryHasAllSkillTypes() {
    XCTAssertEqual(SkillsRegistry.allSkillTypes.count, 2)
}

func testGetSkillTypeById() {
    let skillType = SkillsRegistry.skillType(withId: "weather.forecast")
    XCTAssertNotNil(skillType)
    XCTAssertEqual(skillType?.id, "weather.forecast")
}

func testGenerateManifestIncludesJSONSchema() {
    var config = SkillsConfig()
    config.enabledSkillIds = ["weather.forecast"]
    let registry = SkillsRegistry(config: config)

    let manifest = registry.generateSkillsManifest()

    XCTAssertTrue(manifest.contains("weather.forecast"))
    XCTAssertTrue(manifest.contains("\"type\": \"object\""))
}
```

**Step 2: Run tests to verify they fail**

In Xcode: `Cmd+U`
Expected: FAIL

**Step 3: Rewrite SkillsRegistry**

Replace contents of `HeyLlama/Services/Skills/SkillsRegistry.swift`:

```swift
import Foundation

// MARK: - Skills Registry

/// Central registry for all available skills.
///
/// ## Adding a New Skill
///
/// 1. Create your skill file conforming to `Skill` protocol
/// 2. Add the skill type to `allSkillTypes` below
/// 3. Add a case in `AppleIntelligenceProvider.makeToolForSkill()`
/// 4. Add tests verifying schema matches struct
///
/// See `docs/adding-skills.md` for detailed instructions.
struct SkillsRegistry {

    // MARK: - Registered Skills

    /// All skill types registered in the system.
    ///
    /// To register a new skill, add its type here.
    /// Order determines display order in settings UI.
    static let allSkillTypes: [any Skill.Type] = [
        WeatherForecastSkill.self,
        RemindersAddItemSkill.self,
        // Future skills:
        // CalendarSkill.self,
        // MessagesSkill.self,
        // EmailSkill.self,
    ]

    // MARK: - Instance State

    var enabledSkillIds: Set<String>

    init(config: SkillsConfig = SkillsConfig()) {
        self.enabledSkillIds = Set(config.enabledSkillIds)
    }

    // MARK: - Queries

    /// All registered skill types
    var allSkills: [any Skill.Type] {
        Self.allSkillTypes
    }

    /// Skill types that are currently enabled
    var enabledSkills: [any Skill.Type] {
        Self.allSkillTypes.filter { enabledSkillIds.contains($0.id) }
    }

    /// Get a skill type by its ID
    static func skillType(withId id: String) -> (any Skill.Type)? {
        allSkillTypes.first { $0.id == id }
    }

    /// Get a skill type by its ID (instance method for compatibility)
    func skill(withId id: String) -> (any Skill.Type)? {
        Self.skillType(withId: id)
    }

    /// Check if a skill is enabled
    func isSkillEnabled(_ skillId: String) -> Bool {
        enabledSkillIds.contains(skillId)
    }

    // MARK: - Configuration

    /// Update the skills configuration
    mutating func updateConfig(_ newConfig: SkillsConfig) {
        enabledSkillIds = Set(newConfig.enabledSkillIds)
    }

    // MARK: - Manifest Generation

    /// Generate a manifest of enabled skills for LLM prompt injection.
    ///
    /// For OpenAI-compatible providers, this includes the JSON schema for each skill.
    func generateSkillsManifest() -> String {
        let enabled = enabledSkills

        guard !enabled.isEmpty else {
            return "No skills are currently enabled. Respond with a helpful text message."
        }

        var manifest = "You have access to the following skills (tools). "
        manifest += "You must respond with a single JSON object only. Do not wrap in code fences. "
        manifest += "Do not add extra text before or after the JSON. "
        manifest += "To use a skill, respond with JSON in the format: "
        manifest += "{\"type\":\"call_skills\",\"calls\":[{\"skillId\":\"<id>\",\"arguments\":{...}}]}\n"
        manifest += "To respond with text only, use: {\"type\":\"respond\",\"text\":\"<your response>\"}\n"
        manifest += "Never put tool call JSON inside the \"text\" field.\n\n"
        manifest += "Available skills:\n\n"

        for skillType in enabled {
            manifest += "---\n"
            manifest += "ID: \(skillType.id)\n"
            manifest += "Name: \(skillType.name)\n"
            manifest += "Description: \(skillType.skillDescription)\n"
            manifest += "Arguments schema:\n\(skillType.argumentsJSONSchema)\n\n"
        }

        manifest += "---\n"
        manifest += "IMPORTANT: Always respond with valid JSON. Choose 'respond' for conversational "
        manifest += "replies or 'call_skills' when the user's request matches an available skill.\n"

        return manifest
    }
}

// MARK: - Skill Execution Helper

extension SkillsRegistry {

    /// Execute a skill by ID with JSON arguments.
    ///
    /// This is used by AssistantCoordinator to run skills from LLMActionPlan.
    func executeSkill(
        skillId: String,
        argumentsJSON: String,
        context: SkillContext
    ) async throws -> SkillResult {
        guard let skillType = Self.skillType(withId: skillId) else {
            throw SkillError.skillNotFound(skillId)
        }

        guard isSkillEnabled(skillId) else {
            throw SkillError.skillDisabled(skillId)
        }

        // Decode arguments and execute based on skill type
        switch skillType {
        case is WeatherForecastSkill.Type:
            let args = try JSONDecoder().decode(
                WeatherForecastSkill.Arguments.self,
                from: argumentsJSON.data(using: .utf8)!
            )
            return try await WeatherForecastSkill().execute(arguments: args, context: context)

        case is RemindersAddItemSkill.Type:
            let args = try JSONDecoder().decode(
                RemindersAddItemSkill.Arguments.self,
                from: argumentsJSON.data(using: .utf8)!
            )
            return try await RemindersAddItemSkill().execute(arguments: args, context: context)

        default:
            throw SkillError.skillNotFound(skillId)
        }
    }
}
```

**Step 4: Update SkillsRegistryTests**

```swift
import XCTest
@testable import HeyLlama

final class SkillsRegistryTests: XCTestCase {

    func testRegistryHasBuiltInSkills() {
        XCTAssertEqual(SkillsRegistry.allSkillTypes.count, 2)
    }

    func testGetSkillTypeById() {
        let skillType = SkillsRegistry.skillType(withId: "weather.forecast")
        XCTAssertNotNil(skillType)
        XCTAssertEqual(skillType?.id, "weather.forecast")
    }

    func testGetNonexistentSkill() {
        let skillType = SkillsRegistry.skillType(withId: "nonexistent.skill")
        XCTAssertNil(skillType)
    }

    func testSkillsDisabledByDefault() {
        let registry = SkillsRegistry()
        XCTAssertTrue(registry.enabledSkills.isEmpty)
    }

    func testIsSkillEnabled() {
        var config = SkillsConfig()
        config.enabledSkillIds = ["weather.forecast"]
        let registry = SkillsRegistry(config: config)
        XCTAssertTrue(registry.isSkillEnabled("weather.forecast"))
        XCTAssertFalse(registry.isSkillEnabled("reminders.add_item"))
    }

    func testUpdateConfig() {
        var registry = SkillsRegistry()
        XCTAssertTrue(registry.enabledSkills.isEmpty)

        var newConfig = SkillsConfig()
        newConfig.enabledSkillIds = ["weather.forecast"]
        registry.updateConfig(newConfig)
        XCTAssertEqual(registry.enabledSkills.count, 1)
    }

    func testManifestWhenNoSkillsEnabled() {
        let registry = SkillsRegistry()
        let manifest = registry.generateSkillsManifest()
        XCTAssertTrue(manifest.contains("No skills are currently enabled"))
    }

    func testManifestIncludesJSONSchema() {
        var config = SkillsConfig()
        config.enabledSkillIds = ["weather.forecast"]
        let registry = SkillsRegistry(config: config)

        let manifest = registry.generateSkillsManifest()

        XCTAssertTrue(manifest.contains("weather.forecast"))
        XCTAssertTrue(manifest.contains("\"type\": \"object\""))
    }

    func testSkillsConfigCodable() throws {
        var config = SkillsConfig()
        config.enabledSkillIds = ["weather.forecast", "reminders.add_item"]

        let encoder = JSONEncoder()
        let data = try encoder.encode(config)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(SkillsConfig.self, from: data)

        XCTAssertEqual(decoded.enabledSkillIds, config.enabledSkillIds)
    }

    func testSkillMetadataAccessible() {
        let weatherType = SkillsRegistry.skillType(withId: "weather.forecast")!
        XCTAssertEqual(weatherType.id, "weather.forecast")
        XCTAssertEqual(weatherType.name, "Weather Forecast")
        XCTAssertEqual(weatherType.requiredPermissions, [.location])
        XCTAssertTrue(weatherType.includesInResponseAgent)
    }
}
```

**Step 5: Run tests**

In Xcode: `Cmd+U`
Expected: PASS

**Step 6: Commit**

```bash
git add HeyLlama/Services/Skills/SkillsRegistry.swift HeyLlamaTests/SkillsRegistryTests.swift
git commit -m "refactor(skills): update SkillsRegistry to use Skill types

Registry now uses [any Skill.Type] instead of enum.
Includes executeSkill helper for running skills by ID.
Manifest generation uses skill's JSON schema directly."
```

---

## Task 6: Add Direct Construction to LLMActionPlan

Allow Apple provider to build action plans without JSON serialization.

**Files:**
- Modify: `HeyLlama/Models/LLMActionPlan.swift`
- Add tests to: `HeyLlamaTests/LLMActionPlanTests.swift`

**Step 1: Write failing test**

Add to `HeyLlamaTests/LLMActionPlanTests.swift`:

```swift
func testFromToolInvocationsWithCalls() {
    let calls = [
        SkillCall(skillId: "weather.forecast", arguments: ["when": "today"])
    ]

    let plan = LLMActionPlan.from(responseText: "", toolInvocations: calls)

    if case .callSkills(let resultCalls) = plan {
        XCTAssertEqual(resultCalls.count, 1)
        XCTAssertEqual(resultCalls[0].skillId, "weather.forecast")
    } else {
        XCTFail("Expected callSkills")
    }
}

func testFromToolInvocationsWithoutCalls() {
    let plan = LLMActionPlan.from(responseText: "Hello!", toolInvocations: [])

    if case .respond(let text) = plan {
        XCTAssertEqual(text, "Hello!")
    } else {
        XCTFail("Expected respond")
    }
}
```

**Step 2: Run test to verify it fails**

In Xcode: `Cmd+U`
Expected: FAIL - `from(responseText:toolInvocations:)` doesn't exist

**Step 3: Add direct construction method**

Add to `HeyLlama/Models/LLMActionPlan.swift`:

```swift
/// The action plan returned by the LLM
enum LLMActionPlan: Sendable {
    /// LLM wants to respond with text directly
    case respond(text: String)

    /// LLM wants to call one or more skills
    case callSkills(calls: [SkillCall])

    // MARK: - Construction from OpenAI (JSON parsing)

    /// Parse an action plan from JSON string (for OpenAI-compatible providers)
    static func parse(from jsonString: String) throws -> LLMActionPlan {
        // ... existing implementation ...
    }

    // MARK: - Construction from Apple (direct)

    /// Construct an action plan directly from tool invocations (for Apple provider).
    ///
    /// This avoids unnecessary JSON serialization when using Apple Intelligence,
    /// since the Tool's Arguments are already typed Swift values.
    ///
    /// - Parameters:
    ///   - responseText: The text response from the model (used if no tools called)
    ///   - toolInvocations: Skill calls recorded during tool execution
    /// - Returns: An action plan - either `.callSkills` if tools were invoked, or `.respond` otherwise
    static func from(
        responseText: String,
        toolInvocations: [SkillCall]
    ) -> LLMActionPlan {
        if toolInvocations.isEmpty {
            return .respond(text: responseText)
        }
        return .callSkills(calls: toolInvocations)
    }

    // ... rest of existing code ...
}
```

**Step 4: Run tests**

In Xcode: `Cmd+U`
Expected: PASS

**Step 5: Commit**

```bash
git add HeyLlama/Models/LLMActionPlan.swift HeyLlamaTests/LLMActionPlanTests.swift
git commit -m "feat(llm): add direct construction for LLMActionPlan

Apple provider can now build action plans without JSON round-trip
using LLMActionPlan.from(responseText:toolInvocations:)."
```

---

## Task 7: Update AppleIntelligenceProvider to Use Skill Tools

Collect tools from skills instead of hardcoding.

**Files:**
- Modify: `HeyLlama/Services/LLM/LLMProviders/AppleIntelligenceProvider.swift`
- Modify: `HeyLlamaTests/AppleIntelligenceProviderTests.swift`

**Step 1: Update makeTools to collect from skills**

In `AppleIntelligenceProvider.swift`, update the `makeTools` method:

```swift
#if canImport(FoundationModels)
@available(macOS 26.0, iOS 26.0, *)
private func makeTools(
    recorder: ToolInvocationRecorder,
    includeSkills: Bool
) -> [any Tool] {
    guard includeSkills else { return [] }

    // Collect tools from registered skills
    var tools: [any Tool] = []

    for skillType in SkillsRegistry.allSkillTypes {
        if let tool = makeToolForSkill(skillType, recorder: recorder) {
            tools.append(tool)
        }
    }

    return tools
}

/// Create an Apple Tool for a skill type.
///
/// When adding a new skill, add a case here to return its AppleTool.
/// The switch is necessary because Swift can't dynamically instantiate
/// associated types from the Skill protocol.
private func makeToolForSkill(
    _ skillType: any Skill.Type,
    recorder: ToolInvocationRecorder
) -> (any Tool)? {
    switch skillType {
    case is WeatherForecastSkill.Type:
        return WeatherForecastSkill.AppleTool(recorder: recorder)
    case is RemindersAddItemSkill.Type:
        return RemindersAddItemSkill.AppleTool(recorder: recorder)
    // Future skills:
    // case is CalendarSkill.Type:
    //     return CalendarSkill.AppleTool(recorder: recorder)
    default:
        print("Warning: No Apple Tool registered for skill: \(skillType.id)")
        return nil
    }
}
#endif
```

**Step 2: Update buildActionPlanJSON to use direct construction**

Replace `buildActionPlanJSON` with direct construction:

```swift
static func buildActionPlan(
    responseText: String,
    toolCalls: [ToolInvocation]
) -> LLMActionPlan {
    let skillCalls = toolCalls.map { invocation in
        SkillCall(skillId: invocation.skillId, arguments: invocation.arguments)
    }
    return LLMActionPlan.from(responseText: responseText, toolInvocations: skillCalls)
}
```

**Step 3: Update performCompletion to return LLMActionPlan-compatible string**

The `complete` method still returns `String` for protocol conformance. Update to serialize the action plan:

```swift
let plan = Self.buildActionPlan(responseText: responseText, toolCalls: recordedCalls)

// Serialize to JSON for protocol compatibility
// (AssistantCoordinator will parse this back)
switch plan {
case .respond(let text):
    let payload: [String: Any] = ["type": "respond", "text": text]
    let data = try JSONSerialization.data(withJSONObject: payload)
    return String(data: data, encoding: .utf8) ?? "{\"type\":\"respond\",\"text\":\"\"}"

case .callSkills(let calls):
    let callDicts: [[String: Any]] = calls.map { call in
        ["skillId": call.skillId, "arguments": call.arguments]
    }
    let payload: [String: Any] = ["type": "call_skills", "calls": callDicts]
    let data = try JSONSerialization.data(withJSONObject: payload)
    return String(data: data, encoding: .utf8) ?? "{\"type\":\"call_skills\",\"calls\":[]}"
}
```

**Step 4: Remove hardcoded tool structs**

Delete the inline `WeatherForecastTool` and `RemindersAddItemTool` structs from `AppleIntelligenceProvider.swift` - they now live in the skill files.

**Step 5: Run tests**

In Xcode: `Cmd+U`
Expected: PASS

**Step 6: Commit**

```bash
git add HeyLlama/Services/LLM/LLMProviders/AppleIntelligenceProvider.swift
git commit -m "refactor(llm): collect Apple tools from skill types

AppleIntelligenceProvider now gets tools from SkillsRegistry
instead of hardcoding them. Uses direct LLMActionPlan construction."
```

---

## Task 8: Update AssistantCoordinator to Use New Registry

Update skill execution to use the registry's executeSkill method.

**Files:**
- Modify: `HeyLlama/Core/AssistantCoordinator.swift`
- Verify: `HeyLlamaTests/AssistantCoordinatorSkillsTests.swift`

**Step 1: Update executeSkillCalls**

Replace the skill execution logic in `executeSkillCalls`:

```swift
private func executeSkillCalls(_ calls: [SkillCall], userRequest: String? = nil) async throws -> String {
    var results: [String] = []
    var summaries: [SkillSummary] = []

    for call in calls {
        guard let skillType = SkillsRegistry.skillType(withId: call.skillId) else {
            results.append("I couldn't find the skill '\(call.skillId)'.")
            continue
        }

        guard skillsRegistry.isSkillEnabled(call.skillId) else {
            results.append("The \(skillType.name) skill is currently disabled. You can enable it in Settings.")
            continue
        }

        // Check permissions
        let missing = await permissionManager.missingPermissions(forSkillType: skillType)
        if !missing.isEmpty {
            let missingNames = missing.map { $0.displayName }.joined(separator: ", ")
            let message = "The \(skillType.name) skill requires \(missingNames) permission. Please grant access in System Settings."
            results.append(message)
            if skillType.includesInResponseAgent {
                summaries.append(SkillSummary(
                    skillId: call.skillId,
                    status: .failed,
                    summary: message
                ))
            }
            continue
        }

        // Execute the skill
        do {
            let argsJSON = try call.argumentsAsJSON()
            print("[Skill] Executing \(call.skillId) with arguments: \(argsJSON)")

            let context = SkillContext(
                speaker: currentSpeaker,
                source: .localMic
            )
            let result = try await skillsRegistry.executeSkill(
                skillId: call.skillId,
                argumentsJSON: argsJSON,
                context: context
            )
            print("[Skill] \(call.skillId) result text: \(result.text)")
            results.append(result.text)

            if let summary = result.summary, skillType.includesInResponseAgent {
                summaries.append(summary)
            } else if skillType.includesInResponseAgent {
                summaries.append(SkillSummary(
                    skillId: call.skillId,
                    status: .success,
                    summary: result.text
                ))
            }
        } catch let error as SkillError {
            let message = "Error with \(skillType.name): \(error.localizedDescription)"
            results.append(message)
            if skillType.includesInResponseAgent {
                summaries.append(SkillSummary(
                    skillId: call.skillId,
                    status: .failed,
                    summary: message
                ))
            }
        } catch {
            let message = "An error occurred while running \(skillType.name)."
            results.append(message)
            if skillType.includesInResponseAgent {
                summaries.append(SkillSummary(
                    skillId: call.skillId,
                    status: .failed,
                    summary: message
                ))
            }
        }
    }

    // Use ResponseAgent if we have summaries
    if !summaries.isEmpty {
        do {
            return try await ResponseAgent.generateResponse(
                userRequest: userRequest ?? "User request",
                speakerName: currentSpeaker?.name,
                summaries: summaries,
                llmService: llmService
            )
        } catch {
            print("ResponseAgent failed, using fallback: \(error)")
            return results.joined(separator: " ")
        }
    }

    return results.joined(separator: " ")
}
```

**Step 2: Update SkillPermissionManager**

Add method to check permissions for a skill type:

```swift
func missingPermissions(forSkillType skillType: any Skill.Type) async -> [SkillPermission] {
    var missing: [SkillPermission] = []
    for permission in skillType.requiredPermissions {
        let status = await checkPermissionStatus(permission)
        if status != .granted {
            missing.append(permission)
        }
    }
    return missing
}
```

**Step 3: Run tests**

In Xcode: `Cmd+U`
Expected: PASS

**Step 4: Commit**

```bash
git add HeyLlama/Core/AssistantCoordinator.swift HeyLlama/Services/Skills/SkillPermissionManager.swift
git commit -m "refactor(coordinator): use SkillsRegistry for skill execution

AssistantCoordinator now uses skillsRegistry.executeSkill()
instead of direct RegisteredSkill enum calls."
```

---

## Task 9: Clean Up Old Code

Remove the old `RegisteredSkill` enum and any remaining references.

**Files:**
- Remove: Old `RegisteredSkill` enum from `SkillsRegistry.swift` (if any remains)
- Update: Any remaining references in tests or other files

**Step 1: Search for remaining RegisteredSkill references**

```bash
grep -r "RegisteredSkill" HeyLlama/ HeyLlamaTests/
```

**Step 2: Remove or update each reference**

Replace `RegisteredSkill.weatherForecast` with `WeatherForecastSkill.self` etc.

**Step 3: Run all tests**

In Xcode: `Cmd+U`
Expected: PASS

**Step 4: Commit**

```bash
git add -A
git commit -m "chore: remove old RegisteredSkill enum

All references now use Skill protocol types directly."
```

---

## Task 10: Write Developer Documentation

Create the guide for adding new skills.

**Files:**
- Create: `docs/adding-skills.md`

**Step 1: Write the guide**

Create `docs/adding-skills.md`:

```markdown
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
#if canImport(FoundationModels)
import FoundationModels
#endif

struct MyNewSkill: Skill {

    // MARK: - Metadata

    static let id = "category.skill_name"
    static let name = "My New Skill"
    static let skillDescription = "Brief description for the LLM"
    static let requiredPermissions: [SkillPermission] = []
    static let includesInResponseAgent = true

    // MARK: - Arguments

    struct Arguments: Codable, Sendable {
        let requiredField: String
        let optionalField: String?
    }

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
}

// MARK: - Apple Tool

#if canImport(FoundationModels)
@available(macOS 26.0, iOS 26.0, *)
extension MyNewSkill {
    struct AppleTool: Tool {
        let name = MyNewSkill.id
        let description = MyNewSkill.skillDescription
        let recorder: ToolInvocationRecorder

        @Generable
        struct Arguments: Sendable {
            var requiredField: String
            var optionalField: String?
        }

        func call(arguments: Arguments) async throws -> String {
            var args: [String: Any] = ["requiredField": arguments.requiredField]
            if let opt = arguments.optionalField {
                args["optionalField"] = opt
            }
            await recorder.record(SkillCall(skillId: name, arguments: args))
            return "OK"
        }
    }
}
#endif
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

### 2. Add to AppleIntelligenceProvider

In `HeyLlama/Services/LLM/LLMProviders/AppleIntelligenceProvider.swift`:

```swift
private func makeToolForSkill(...) -> (any Tool)? {
    switch skillType {
    case is WeatherForecastSkill.Type:
        return WeatherForecastSkill.AppleTool(recorder: recorder)
    case is MyNewSkill.Type:  // Add here
        return MyNewSkill.AppleTool(recorder: recorder)
    default:
        return nil
    }
}
```

### 3. Write Tests

Create `HeyLlamaTests/MyNewSkillTests.swift`:

```swift
import XCTest
@testable import HeyLlama

final class MyNewSkillTests: XCTestCase {

    func testArgumentsMatchJSONSchema() throws {
        try SkillSchemaValidator.validate(
            structType: MyNewSkill.Arguments.self,
            jsonSchema: MyNewSkill.argumentsJSONSchema
        )
    }

    func testJSONSchemaIsValidJSON() {
        let data = MyNewSkill.argumentsJSONSchema.data(using: .utf8)!
        XCTAssertNoThrow(try JSONSerialization.jsonObject(with: data))
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

Tests verify this automatically.

## Permissions

If your skill needs system permissions:

```swift
static let requiredPermissions: [SkillPermission] = [.location, .reminders]
```

Available permissions:
- `.location` - GPS location
- `.reminders` - Apple Reminders
- `.calendar` - Apple Calendar (future)
- `.contacts` - Contacts (future)

## Common Patterns

### Enum Arguments

```swift
struct Arguments: Codable, Sendable {
    let period: String  // Use String, validate in execute()
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
struct Arguments: Codable, Sendable {
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

## Troubleshooting

**Schema validation test fails**
- Check property names match exactly
- Check required array matches non-optional properties
- Check types match (String->string, Int->integer, etc.)

**Skill not appearing in LLM responses**
- Verify skill is in `SkillsRegistry.allSkillTypes`
- Verify skill ID is in enabled skills config
- Check LLM manifest includes the skill

**Apple Tool not working**
- Verify case exists in `makeToolForSkill()`
- Check `@Generable` macro is applied to Arguments
- Verify macOS 26+ / iOS 26+
```

**Step 2: Commit**

```bash
git add docs/adding-skills.md
git commit -m "docs: add guide for adding new skills

Comprehensive guide covering:
- Template skill file
- Registration checklist
- Schema sync rules
- Common patterns
- Troubleshooting"
```

---

## Task 11: Final Integration Test

Run the full test suite and verify everything works.

**Step 1: Run all tests**

In Xcode: `Cmd+U`
Expected: All tests PASS

**Step 2: Manual verification**

1. Build the app (`Cmd+B`)
2. Run the app (`Cmd+R`)
3. Enable a skill in settings
4. Test with both Apple Intelligence and OpenAI provider (if available)

**Step 3: Final commit**

```bash
git add -A
git commit -m "feat(skills): complete skill architecture refactor

Skills are now self-contained with:
- Skill protocol with static metadata
- Arguments struct + JSON schema co-located
- Apple Tool in #if canImport block
- Schema validation tests

See docs/adding-skills.md for guide."
```

---

## Summary

After completing all tasks, you will have:

1. **Skill protocol** - Unified interface for all skills
2. **Schema validator** - Test utility ensuring structs match JSON schemas
3. **Refactored skills** - WeatherForecast and RemindersAddItem using new pattern
4. **Updated registry** - Uses skill types instead of enum
5. **Direct action plan construction** - No JSON round-trip for Apple
6. **Updated providers** - Apple collects tools from skills
7. **Updated coordinator** - Uses registry's executeSkill
8. **Documentation** - Complete guide for adding new skills
