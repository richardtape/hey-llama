import XCTest
@testable import HeyLlama

final class SkillArgumentParsingTests: XCTestCase {
    private struct SampleArgs: Codable, Equatable {
        let name: String
    }

    func testDecodeArgumentsParsesValidJSON() throws {
        let args: SampleArgs = try SkillArgumentParsing.decodeArguments(from: "{\"name\":\"Llama\"}")
        XCTAssertEqual(args, SampleArgs(name: "Llama"))
    }

    func testDecodeArgumentsThrowsInvalidArguments() {
        XCTAssertThrowsError(try SkillArgumentParsing.decodeArguments(from: "not json") as SampleArgs) { error in
            guard case SkillError.invalidArguments = error else {
                XCTFail("Expected invalidArguments error, got \(error)")
                return
            }
        }
    }
}
