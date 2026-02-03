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
