import XCTest
@testable import HeyLlama

final class ResponseAgentTests: XCTestCase {
    func testBuildPromptIncludesRequestAndSummaries() {
        let summaries = [
            SkillSummary(skillId: "weather.forecast", status: .success, summary: "Cloudy", details: [:])
        ]
        let prompt = ResponseAgent.buildPrompt(
            userRequest: "What's the weather?",
            summaries: summaries
        )
        XCTAssertTrue(prompt.contains("What's the weather?"))
        XCTAssertTrue(prompt.contains("weather.forecast"))
        XCTAssertTrue(prompt.contains("Cloudy"))
    }
}
