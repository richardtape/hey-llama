import Foundation
import WeatherKit
import CoreLocation
#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Arguments

/// Arguments for the weather forecast skill.
///
/// IMPORTANT: When modifying this struct, you MUST update `argumentsJSONSchema`
/// to match. Run `WeatherForecastSkillTests.testArgumentsMatchJSONSchema` to verify.
struct WeatherForecastArguments: Codable {
    /// Time period for the forecast: "today", "tomorrow", or "next_7_days"
    let when: String

    /// Geographic location name (city, region, address).
    /// Omit to use the user's GPS location.
    let location: String?
}

// MARK: - Skill Definition

/// Weather forecast skill using WeatherKit.
///
/// Provides current conditions and forecasts for today, tomorrow, or 7 days.
/// Uses GPS location by default, or a specified location name.
struct WeatherForecastSkill: Skill {

    // MARK: - Skill Metadata

    static let id = "weather.forecast"
    static let name = "Weather Forecast"
    static let skillDescription = "Get the weather forecast for today, tomorrow, or the next 7 days"
    static let requiredPermissions: [SkillPermission] = [.location]
    static let includesInResponseAgent = true

    // MARK: - Arguments Type Alias

    typealias Arguments = WeatherForecastArguments

    // MARK: - JSON Schema

    /// JSON Schema for OpenAI-compatible providers.
    ///
    /// IMPORTANT: This schema MUST match the `Arguments` struct above.
    /// - Property names must be identical
    /// - Types must match (String -> "string", Int -> "integer", etc.)
    /// - Required fields must be non-optional in the struct
    /// - Optional fields must be optional (?) in the struct
    ///
    /// NOTE: The location description is intentionally detailed to prevent LLMs from
    /// passing the speaker's name as a location. Without this guidance, LLMs often
    /// interpret "my weather" as meaning the speaker's name rather than GPS location.
    static let argumentsJSONSchema = """
        {
            "type": "object",
            "properties": {
                "when": {
                    "type": "string",
                    "enum": ["today", "tomorrow", "next_7_days"],
                    "description": "The time period for the forecast"
                },
                "location": {
                    "type": "string",
                    "description": "A geographic place name (city, region, or address) like 'New York', 'London', or 'Tokyo'. ONLY include this if the user explicitly names a place. Do NOT pass the user's name here. Omit this parameter entirely when the user says 'my weather' or doesn't specify a location - their GPS location will be used automatically."
                }
            },
            "required": ["when"]
        }
        """

    // MARK: - Execution

    func execute(arguments: Arguments, context: SkillContext) async throws -> SkillResult {
        // Parse the time period
        let period = parseTimePeriod(arguments.when)

        // Normalize location, filtering out speaker name if LLM incorrectly passed it
        let normalizedLocation = LocationHelpers.normalizeLocationToken(
            arguments.location,
            speakerName: context.speaker?.name
        )

        // Get location
        let location: CLLocation
        if let locationName = normalizedLocation {
            location = try await LocationHelpers.geocodeLocation(locationName)
        } else {
            location = try await LocationHelpers.getCurrentLocation()
        }

        // Fetch weather
        let weatherService = WeatherService.shared
        let weather = try await weatherService.weather(for: location)

        // Format response
        let responseText = formatWeatherResponse(
            weather: weather,
            period: period,
            locationName: normalizedLocation
        )

        let summary = SkillSummary(
            skillId: Self.id,
            status: .success,
            summary: responseText,
            details: [
                "temperature": weather.currentWeather.temperature.value,
                "temperatureUnit": weather.currentWeather.temperature.unit.symbol,
                "condition": weather.currentWeather.condition.description
            ]
        )

        return SkillResult(text: responseText, data: [
            "temperature": weather.currentWeather.temperature.value,
            "temperatureUnit": weather.currentWeather.temperature.unit.symbol,
            "condition": weather.currentWeather.condition.description
        ], summary: summary)
    }

    // MARK: - Legacy API Support

    /// Run with JSON arguments string (for backward compatibility with RegisteredSkill)
    func run(argumentsJSON: String, context: SkillContext) async throws -> SkillResult {
        guard let data = argumentsJSON.data(using: .utf8) else {
            throw SkillError.invalidArguments("Invalid JSON encoding")
        }

        do {
            let args = try JSONDecoder().decode(Arguments.self, from: data)
            return try await execute(arguments: args, context: context)
        } catch let error as SkillError {
            throw error
        } catch {
            throw SkillError.invalidArguments("Failed to parse arguments: \(error.localizedDescription)")
        }
    }

    // MARK: - Private Helpers

    private enum TimePeriod {
        case today
        case tomorrow
        case next7Days
    }

    private func parseTimePeriod(_ value: String) -> TimePeriod {
        switch value.lowercased() {
        case "tomorrow": return .tomorrow
        case "next_7_days", "next7days", "week": return .next7Days
        default: return .today
        }
    }

    private func formatTemperature(_ measurement: Measurement<UnitTemperature>) -> String {
        let value = measurement.value
        let rounded = (value * 2).rounded() / 2
        let unit = measurement.unit.symbol
        if rounded == rounded.rounded() {
            return "\(Int(rounded))\(unit)"
        } else {
            return String(format: "%.1f%@", rounded, unit)
        }
    }

    private func formatWeatherResponse(
        weather: Weather,
        period: TimePeriod,
        locationName: String?
    ) -> String {
        let locationStr = locationName ?? "your location"
        let current = weather.currentWeather

        switch period {
        case .today:
            let temp = formatTemperature(current.temperature)
            let condition = current.condition.description
            let high = weather.dailyForecast.first.map { formatTemperature($0.highTemperature) } ?? "N/A"
            let low = weather.dailyForecast.first.map { formatTemperature($0.lowTemperature) } ?? "N/A"
            return "The weather in \(locationStr) today is \(condition) with a current temperature of \(temp). Expected high of \(high) and low of \(low)."

        case .tomorrow:
            guard weather.dailyForecast.count > 1 else {
                return "Tomorrow's forecast is not available."
            }
            let tomorrow = weather.dailyForecast[1]
            let condition = tomorrow.condition.description
            let high = formatTemperature(tomorrow.highTemperature)
            let low = formatTemperature(tomorrow.lowTemperature)
            return "Tomorrow in \(locationStr) will be \(condition) with a high of \(high) and low of \(low)."

        case .next7Days:
            var forecast = "Here's the 7-day forecast for \(locationStr):\n"
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "EEEE"

            for (index, day) in weather.dailyForecast.prefix(7).enumerated() {
                let dayName = index == 0 ? "Today" : dateFormatter.string(from: day.date)
                let condition = day.condition.description
                let high = formatTemperature(day.highTemperature)
                let low = formatTemperature(day.lowTemperature)
                forecast += "- \(dayName): \(condition), \(high)/\(low)\n"
            }
            return forecast
        }
    }
}
