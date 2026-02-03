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
            structType: WeatherForecastArguments.self,
            jsonSchema: WeatherForecastSkill.argumentsJSONSchema
        )
    }

    // MARK: - Argument Decoding Tests

    func testCanDecodeArgumentsFromJSON() throws {
        let json = """
            {"when": "today", "location": "San Francisco"}
            """
        let data = json.data(using: .utf8)!
        let args = try JSONDecoder().decode(WeatherForecastArguments.self, from: data)

        XCTAssertEqual(args.when, "today")
        XCTAssertEqual(args.location, "San Francisco")
    }

    func testCanDecodeArgumentsWithoutLocation() throws {
        let json = """
            {"when": "tomorrow"}
            """
        let data = json.data(using: .utf8)!
        let args = try JSONDecoder().decode(WeatherForecastArguments.self, from: data)

        XCTAssertEqual(args.when, "tomorrow")
        XCTAssertNil(args.location)
    }

    func testCanDecodeNext7DaysArguments() throws {
        let json = """
            {"when": "next_7_days"}
            """
        let data = json.data(using: .utf8)!
        let args = try JSONDecoder().decode(WeatherForecastArguments.self, from: data)

        XCTAssertEqual(args.when, "next_7_days")
    }

    // MARK: - Location Normalization Tests

    func testNormalizeLocationTokenReturnsNilForUserLocation() {
        XCTAssertNil(LocationHelpers.normalizeLocationToken("user"))
    }

}
