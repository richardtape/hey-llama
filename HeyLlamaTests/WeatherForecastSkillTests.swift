import XCTest
@testable import HeyLlama

final class WeatherForecastSkillTests: XCTestCase {

    func testSkillHasCorrectId() {
        let skill = RegisteredSkill.weatherForecast
        XCTAssertEqual(skill.id, "weather.forecast")
    }

    func testSkillRequiresLocationPermission() {
        let skill = RegisteredSkill.weatherForecast
        XCTAssertTrue(skill.requiredPermissions.contains(.location))
    }

    func testArgumentSchemaIsValidJSON() {
        let skill = RegisteredSkill.weatherForecast
        let schemaData = skill.argumentSchemaJSON.data(using: .utf8)!

        XCTAssertNoThrow(try JSONSerialization.jsonObject(with: schemaData))
    }

    func testParseWeatherArguments() throws {
        let args = try WeatherForecastSkill.parseArguments(from: """
        {"when": "today", "location": "San Francisco"}
        """)

        XCTAssertEqual(args.when, .today)
        XCTAssertEqual(args.location, "San Francisco")
    }

    func testParseWeatherArgumentsWithoutLocation() throws {
        let args = try WeatherForecastSkill.parseArguments(from: """
        {"when": "tomorrow"}
        """)

        XCTAssertEqual(args.when, .tomorrow)
        XCTAssertNil(args.location)
    }

    func testParseWeatherArgumentsNormalizesUserLocation() throws {
        let args = try WeatherForecastSkill.parseArguments(from: """
        {"when": "today", "location": "user"}
        """)

        XCTAssertEqual(args.when, .today)
        XCTAssertNil(args.location)
    }

    func testParseWeatherArgumentsNext7Days() throws {
        let args = try WeatherForecastSkill.parseArguments(from: """
        {"when": "next_7_days"}
        """)

        XCTAssertEqual(args.when, .next7Days)
        XCTAssertNil(args.location)
    }

    func testParseWeatherArgumentsInvalidWhen() {
        XCTAssertThrowsError(try WeatherForecastSkill.parseArguments(from: """
        {"when": "invalid"}
        """)) { error in
            guard case SkillError.invalidArguments = error else {
                XCTFail("Expected invalidArguments error, got \(error)")
                return
            }
        }
    }

    func testParseWeatherArgumentsMissingWhen() {
        XCTAssertThrowsError(try WeatherForecastSkill.parseArguments(from: """
        {"location": "Paris"}
        """)) { error in
            guard case SkillError.invalidArguments = error else {
                XCTFail("Expected invalidArguments error, got \(error)")
                return
            }
        }
    }

    func testParseWeatherArgumentsInvalidJSON() {
        XCTAssertThrowsError(try WeatherForecastSkill.parseArguments(from: "not json")) { error in
            guard case SkillError.invalidArguments = error else {
                XCTFail("Expected invalidArguments error, got \(error)")
                return
            }
        }
    }

    func testTimePeriodDescription() {
        XCTAssertEqual(WeatherForecastSkill.TimePeriod.today.description, "today")
        XCTAssertEqual(WeatherForecastSkill.TimePeriod.tomorrow.description, "tomorrow")
        XCTAssertEqual(WeatherForecastSkill.TimePeriod.next7Days.description, "next 7 days")
    }
}
