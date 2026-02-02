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
