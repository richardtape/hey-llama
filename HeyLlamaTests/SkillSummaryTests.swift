import XCTest
@testable import HeyLlama

final class SkillSummaryTests: XCTestCase {
    func testSummaryEncodesToJSON() throws {
        let summary = SkillSummary(
            skillId: "weather.forecast",
            status: .success,
            summary: "Weather retrieved",
            details: ["temperature": 12.3]
        )

        let data = try summary.toJSONData()
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(json?["skillId"] as? String, "weather.forecast")
        XCTAssertEqual(json?["status"] as? String, "success")
    }
}
