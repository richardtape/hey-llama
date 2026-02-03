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

    /// Extract properties from a Codable struct using a custom decoder
    static func extractStructProperties<T: Codable>(_ type: T.Type) throws -> [SchemaProperty] {
        let decoder = PropertyExtractingDecoder()

        // This will capture all property accesses
        _ = try? T(from: decoder)

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

// MARK: - Property Extracting Decoder

/// A decoder that captures property names and types by returning default values
/// instead of throwing, allowing the full struct to be decoded.
private class PropertyExtractingDecoder: Decoder {
    var codingPath: [CodingKey] = []
    var userInfo: [CodingUserInfoKey: Any] = [:]
    var capturedProperties: [SkillSchemaValidator.SchemaProperty] = []

    func container<Key: CodingKey>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> {
        return KeyedDecodingContainer(PropertyExtractingKeyedContainer<Key>(decoder: self))
    }

    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        return PropertyExtractingUnkeyedContainer(decoder: self)
    }

    func singleValueContainer() throws -> SingleValueDecodingContainer {
        return PropertyExtractingSingleValueContainer(decoder: self)
    }
}

private struct PropertyExtractingKeyedContainer<K: CodingKey>: KeyedDecodingContainerProtocol {
    typealias Key = K

    var codingPath: [CodingKey] = []
    var allKeys: [K] = []
    let decoder: PropertyExtractingDecoder

    init(decoder: PropertyExtractingDecoder) {
        self.decoder = decoder
    }

    func contains(_ key: K) -> Bool { true }

    func decodeNil(forKey key: K) throws -> Bool {
        return false // Say it's not nil so decoding continues
    }

    // Required property decoders - return default values
    func decode(_ type: Bool.Type, forKey key: K) throws -> Bool {
        decoder.capturedProperties.append(SkillSchemaValidator.SchemaProperty(
            name: key.stringValue, type: "boolean", isRequired: true
        ))
        return false
    }

    func decode(_ type: String.Type, forKey key: K) throws -> String {
        decoder.capturedProperties.append(SkillSchemaValidator.SchemaProperty(
            name: key.stringValue, type: "string", isRequired: true
        ))
        return ""
    }

    func decode(_ type: Double.Type, forKey key: K) throws -> Double {
        decoder.capturedProperties.append(SkillSchemaValidator.SchemaProperty(
            name: key.stringValue, type: "number", isRequired: true
        ))
        return 0.0
    }

    func decode(_ type: Float.Type, forKey key: K) throws -> Float {
        decoder.capturedProperties.append(SkillSchemaValidator.SchemaProperty(
            name: key.stringValue, type: "number", isRequired: true
        ))
        return 0.0
    }

    func decode(_ type: Int.Type, forKey key: K) throws -> Int {
        decoder.capturedProperties.append(SkillSchemaValidator.SchemaProperty(
            name: key.stringValue, type: "integer", isRequired: true
        ))
        return 0
    }

    func decode(_ type: Int8.Type, forKey key: K) throws -> Int8 { 0 }
    func decode(_ type: Int16.Type, forKey key: K) throws -> Int16 { 0 }
    func decode(_ type: Int32.Type, forKey key: K) throws -> Int32 { 0 }
    func decode(_ type: Int64.Type, forKey key: K) throws -> Int64 { 0 }
    func decode(_ type: UInt.Type, forKey key: K) throws -> UInt { 0 }
    func decode(_ type: UInt8.Type, forKey key: K) throws -> UInt8 { 0 }
    func decode(_ type: UInt16.Type, forKey key: K) throws -> UInt16 { 0 }
    func decode(_ type: UInt32.Type, forKey key: K) throws -> UInt32 { 0 }
    func decode(_ type: UInt64.Type, forKey key: K) throws -> UInt64 { 0 }

    func decode<T: Decodable>(_ type: T.Type, forKey key: K) throws -> T {
        let typeName = mapSwiftTypeToJSONType(type)
        decoder.capturedProperties.append(SkillSchemaValidator.SchemaProperty(
            name: key.stringValue, type: typeName, isRequired: true
        ))
        // Try to decode nested types
        let nestedDecoder = PropertyExtractingDecoder()
        return try T(from: nestedDecoder)
    }

    // Optional property decoders
    func decodeIfPresent(_ type: Bool.Type, forKey key: K) throws -> Bool? {
        decoder.capturedProperties.append(SkillSchemaValidator.SchemaProperty(
            name: key.stringValue, type: "boolean", isRequired: false
        ))
        return nil
    }

    func decodeIfPresent(_ type: String.Type, forKey key: K) throws -> String? {
        decoder.capturedProperties.append(SkillSchemaValidator.SchemaProperty(
            name: key.stringValue, type: "string", isRequired: false
        ))
        return nil
    }

    func decodeIfPresent(_ type: Double.Type, forKey key: K) throws -> Double? {
        decoder.capturedProperties.append(SkillSchemaValidator.SchemaProperty(
            name: key.stringValue, type: "number", isRequired: false
        ))
        return nil
    }

    func decodeIfPresent(_ type: Float.Type, forKey key: K) throws -> Float? {
        decoder.capturedProperties.append(SkillSchemaValidator.SchemaProperty(
            name: key.stringValue, type: "number", isRequired: false
        ))
        return nil
    }

    func decodeIfPresent(_ type: Int.Type, forKey key: K) throws -> Int? {
        decoder.capturedProperties.append(SkillSchemaValidator.SchemaProperty(
            name: key.stringValue, type: "integer", isRequired: false
        ))
        return nil
    }

    func decodeIfPresent(_ type: Int8.Type, forKey key: K) throws -> Int8? { nil }
    func decodeIfPresent(_ type: Int16.Type, forKey key: K) throws -> Int16? { nil }
    func decodeIfPresent(_ type: Int32.Type, forKey key: K) throws -> Int32? { nil }
    func decodeIfPresent(_ type: Int64.Type, forKey key: K) throws -> Int64? { nil }
    func decodeIfPresent(_ type: UInt.Type, forKey key: K) throws -> UInt? { nil }
    func decodeIfPresent(_ type: UInt8.Type, forKey key: K) throws -> UInt8? { nil }
    func decodeIfPresent(_ type: UInt16.Type, forKey key: K) throws -> UInt16? { nil }
    func decodeIfPresent(_ type: UInt32.Type, forKey key: K) throws -> UInt32? { nil }
    func decodeIfPresent(_ type: UInt64.Type, forKey key: K) throws -> UInt64? { nil }

    func decodeIfPresent<T: Decodable>(_ type: T.Type, forKey key: K) throws -> T? {
        let typeName = mapSwiftTypeToJSONType(type)
        decoder.capturedProperties.append(SkillSchemaValidator.SchemaProperty(
            name: key.stringValue, type: typeName, isRequired: false
        ))
        return nil
    }

    func nestedContainer<NestedKey: CodingKey>(keyedBy type: NestedKey.Type, forKey key: K) throws -> KeyedDecodingContainer<NestedKey> {
        return KeyedDecodingContainer(PropertyExtractingKeyedContainer<NestedKey>(decoder: decoder))
    }

    func nestedUnkeyedContainer(forKey key: K) throws -> UnkeyedDecodingContainer {
        return PropertyExtractingUnkeyedContainer(decoder: decoder)
    }

    func superDecoder() throws -> Decoder { decoder }
    func superDecoder(forKey key: K) throws -> Decoder { decoder }

    private func mapSwiftTypeToJSONType<T>(_ type: T.Type) -> String {
        let typeName = String(describing: type)
        switch typeName {
        case "String": return "string"
        case "Int", "Int8", "Int16", "Int32", "Int64",
             "UInt", "UInt8", "UInt16", "UInt32", "UInt64": return "integer"
        case "Double", "Float": return "number"
        case "Bool": return "boolean"
        default:
            if typeName.hasPrefix("Array") { return "array" }
            return "string"
        }
    }
}

private struct PropertyExtractingUnkeyedContainer: UnkeyedDecodingContainer {
    var codingPath: [CodingKey] = []
    var count: Int? = 0
    var isAtEnd: Bool = true
    var currentIndex: Int = 0
    let decoder: PropertyExtractingDecoder

    init(decoder: PropertyExtractingDecoder) {
        self.decoder = decoder
    }

    mutating func decodeNil() throws -> Bool { true }
    mutating func decode(_ type: Bool.Type) throws -> Bool { false }
    mutating func decode(_ type: String.Type) throws -> String { "" }
    mutating func decode(_ type: Double.Type) throws -> Double { 0 }
    mutating func decode(_ type: Float.Type) throws -> Float { 0 }
    mutating func decode(_ type: Int.Type) throws -> Int { 0 }
    mutating func decode(_ type: Int8.Type) throws -> Int8 { 0 }
    mutating func decode(_ type: Int16.Type) throws -> Int16 { 0 }
    mutating func decode(_ type: Int32.Type) throws -> Int32 { 0 }
    mutating func decode(_ type: Int64.Type) throws -> Int64 { 0 }
    mutating func decode(_ type: UInt.Type) throws -> UInt { 0 }
    mutating func decode(_ type: UInt8.Type) throws -> UInt8 { 0 }
    mutating func decode(_ type: UInt16.Type) throws -> UInt16 { 0 }
    mutating func decode(_ type: UInt32.Type) throws -> UInt32 { 0 }
    mutating func decode(_ type: UInt64.Type) throws -> UInt64 { 0 }
    mutating func decode<T: Decodable>(_ type: T.Type) throws -> T {
        try T(from: decoder)
    }
    mutating func nestedContainer<NestedKey: CodingKey>(keyedBy type: NestedKey.Type) throws -> KeyedDecodingContainer<NestedKey> {
        KeyedDecodingContainer(PropertyExtractingKeyedContainer<NestedKey>(decoder: decoder))
    }
    mutating func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
        PropertyExtractingUnkeyedContainer(decoder: decoder)
    }
    mutating func superDecoder() throws -> Decoder { decoder }
}

private struct PropertyExtractingSingleValueContainer: SingleValueDecodingContainer {
    var codingPath: [CodingKey] = []
    let decoder: PropertyExtractingDecoder

    init(decoder: PropertyExtractingDecoder) {
        self.decoder = decoder
    }

    func decodeNil() -> Bool { false }
    func decode(_ type: Bool.Type) throws -> Bool { false }
    func decode(_ type: String.Type) throws -> String { "" }
    func decode(_ type: Double.Type) throws -> Double { 0 }
    func decode(_ type: Float.Type) throws -> Float { 0 }
    func decode(_ type: Int.Type) throws -> Int { 0 }
    func decode(_ type: Int8.Type) throws -> Int8 { 0 }
    func decode(_ type: Int16.Type) throws -> Int16 { 0 }
    func decode(_ type: Int32.Type) throws -> Int32 { 0 }
    func decode(_ type: Int64.Type) throws -> Int64 { 0 }
    func decode(_ type: UInt.Type) throws -> UInt { 0 }
    func decode(_ type: UInt8.Type) throws -> UInt8 { 0 }
    func decode(_ type: UInt16.Type) throws -> UInt16 { 0 }
    func decode(_ type: UInt32.Type) throws -> UInt32 { 0 }
    func decode(_ type: UInt64.Type) throws -> UInt64 { 0 }
    func decode<T: Decodable>(_ type: T.Type) throws -> T {
        try T(from: decoder)
    }
}
