import XCTest
@testable import HeyLlama

final class ResponseAgentTests: XCTestCase {
    func testBuildPromptIncludesSpeakerAndSummaries() {
        let summaries = [
            SkillSummary(skillId: "weather.forecast", status: .success, summary: "Cloudy", details: [:])
        ]
        let prompt = ResponseAgent.buildPrompt(
            userRequest: "What's the weather?",
            speakerName: "Rich",
            summaries: summaries
        )
        XCTAssertTrue(prompt.contains("Rich"))
        XCTAssertTrue(prompt.contains("weather.forecast"))
    }
}
