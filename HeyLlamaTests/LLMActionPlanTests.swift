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

    // MARK: - Edge Cases

    func testDecodeEmptyCallsArray() throws {
        let json = """
        {"type":"call_skills","calls":[]}
        """

        let plan = try LLMActionPlan.parse(from: json)

        guard case .callSkills(let calls) = plan else {
            XCTFail("Expected call_skills action")
            return
        }

        XCTAssertTrue(calls.isEmpty)
    }

    func testDecodeSkillCallWithEmptyArguments() throws {
        let json = """
        {"type":"call_skills","calls":[{"skillId":"test","arguments":{}}]}
        """

        let plan = try LLMActionPlan.parse(from: json)

        guard case .callSkills(let calls) = plan else {
            XCTFail("Expected call_skills action")
            return
        }

        XCTAssertEqual(calls.count, 1)
        XCTAssertTrue(calls[0].arguments.isEmpty)
    }

    func testDecodeSkillCallWithMissingArguments() throws {
        let json = """
        {"type":"call_skills","calls":[{"skillId":"test"}]}
        """

        let plan = try LLMActionPlan.parse(from: json)

        guard case .callSkills(let calls) = plan else {
            XCTFail("Expected call_skills action")
            return
        }

        XCTAssertEqual(calls.count, 1)
        XCTAssertTrue(calls[0].arguments.isEmpty)
    }

    // MARK: - Markdown Code Fence Stripping Tests

    func testDecodeWithMarkdownJsonCodeFence() throws {
        let json = """
        ```json
        {"type":"respond","text":"Hello!"}
        ```
        """

        let plan = try LLMActionPlan.parse(from: json)

        guard case .respond(let text) = plan else {
            XCTFail("Expected respond action")
            return
        }

        XCTAssertEqual(text, "Hello!")
    }

    func testDecodeWithMarkdownPlainCodeFence() throws {
        let json = """
        ```
        {"type":"respond","text":"Hello!"}
        ```
        """

        let plan = try LLMActionPlan.parse(from: json)

        guard case .respond(let text) = plan else {
            XCTFail("Expected respond action")
            return
        }

        XCTAssertEqual(text, "Hello!")
    }

    func testDecodeCallSkillsWithMarkdownCodeFence() throws {
        let json = """
        ```json
        {"type":"call_skills","calls":[{"skillId":"weather.forecast","arguments":{"when":"today"}}]}
        ```
        """

        let plan = try LLMActionPlan.parse(from: json)

        guard case .callSkills(let calls) = plan else {
            XCTFail("Expected call_skills action")
            return
        }

        XCTAssertEqual(calls.count, 1)
        XCTAssertEqual(calls[0].skillId, "weather.forecast")
    }

    func testDecodeWithLeadingAndTrailingText() throws {
        let json = """
        Sure! Here's the result:
        {"type":"respond","text":"Hello from JSON"}
        Thanks!
        """

        let plan = try LLMActionPlan.parse(from: json)

        guard case .respond(let text) = plan else {
            XCTFail("Expected respond action")
            return
        }

        XCTAssertEqual(text, "Hello from JSON")
    }
}
