import Foundation
import WeatherKit
import CoreLocation

/// Weather forecast skill using WeatherKit
struct WeatherForecastSkill {

    // MARK: - Argument Types

    enum TimePeriod: String, Codable, CustomStringConvertible {
        case today
        case tomorrow
        case next7Days = "next_7_days"

        var description: String {
            switch self {
            case .today: return "today"
            case .tomorrow: return "tomorrow"
            case .next7Days: return "next 7 days"
            }
        }
    }

    struct Arguments: Codable {
        let when: TimePeriod
        let location: String?
    }

    // MARK: - Argument Parsing

    static func parseArguments(from json: String) throws -> Arguments {
        guard let data = json.data(using: .utf8) else {
            throw SkillError.invalidArguments("Invalid JSON encoding")
        }

        do {
            return try JSONDecoder().decode(Arguments.self, from: data)
        } catch {
            throw SkillError.invalidArguments("Failed to parse arguments: \(error.localizedDescription)")
        }
    }

    // MARK: - Execution

    func run(argumentsJSON: String, context: SkillContext) async throws -> SkillResult {
        let args = try Self.parseArguments(from: argumentsJSON)

        // Get location
        let location: CLLocation
        if let locationName = args.location {
            location = try await geocodeLocation(locationName)
        } else {
            location = try await getCurrentLocation()
        }

        // Fetch weather
        let weatherService = WeatherService.shared
        let weather = try await weatherService.weather(for: location)

        // Format response based on time period
        let responseText = formatWeatherResponse(
            weather: weather,
            period: args.when,
            locationName: args.location
        )

        return SkillResult(text: responseText, data: [
            "temperature": weather.currentWeather.temperature.value,
            "temperatureUnit": weather.currentWeather.temperature.unit.symbol,
            "condition": weather.currentWeather.condition.description
        ])
    }

    // MARK: - Private Helpers

    private func geocodeLocation(_ name: String) async throws -> CLLocation {
        let geocoder = CLGeocoder()

        do {
            let placemarks = try await geocoder.geocodeAddressString(name)

            guard let placemark = placemarks.first,
                  let location = placemark.location else {
                throw SkillError.executionFailed("Could not find location: \(name)")
            }

            return location
        } catch let error as SkillError {
            throw error
        } catch {
            throw SkillError.executionFailed("Geocoding error: \(error.localizedDescription)")
        }
    }

    private func getCurrentLocation() async throws -> CLLocation {
        let locationFetcher = LocationFetcher()
        return try await locationFetcher.getCurrentLocation()
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
            let temp = current.temperature.formatted()
            let condition = current.condition.description
            let high = weather.dailyForecast.first?.highTemperature.formatted() ?? "N/A"
            let low = weather.dailyForecast.first?.lowTemperature.formatted() ?? "N/A"

            return "The weather in \(locationStr) today is \(condition) with a current temperature of \(temp). Expected high of \(high) and low of \(low)."

        case .tomorrow:
            guard weather.dailyForecast.count > 1 else {
                return "Tomorrow's forecast is not available."
            }
            let tomorrow = weather.dailyForecast[1]
            let condition = tomorrow.condition.description
            let high = tomorrow.highTemperature.formatted()
            let low = tomorrow.lowTemperature.formatted()

            return "Tomorrow in \(locationStr) will be \(condition) with a high of \(high) and low of \(low)."

        case .next7Days:
            var forecast = "Here's the 7-day forecast for \(locationStr):\n"
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "EEEE"

            for (index, day) in weather.dailyForecast.prefix(7).enumerated() {
                let dayName = index == 0 ? "Today" : dateFormatter.string(from: day.date)
                let condition = day.condition.description
                let high = day.highTemperature.formatted()
                let low = day.lowTemperature.formatted()
                forecast += "• \(dayName): \(condition), \(high)/\(low)\n"
            }

            return forecast
        }
    }
}

// MARK: - Location Fetcher

/// Helper to get current location using CLLocationManager
private actor LocationFetcher: NSObject {
    private var manager: CLLocationManager?
    private var continuation: CheckedContinuation<CLLocation, Error>?

    func getCurrentLocation() async throws -> CLLocation {
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation

            Task { @MainActor in
                let manager = CLLocationManager()
                manager.delegate = self
                manager.desiredAccuracy = kCLLocationAccuracyKilometer

                // Store reference to manager
                await self.setManager(manager)

                // Check authorization and request location
                switch manager.authorizationStatus {
                case .authorizedAlways, .authorized:
                    manager.requestLocation()
                case .notDetermined:
                    manager.requestWhenInUseAuthorization()
                default:
                    await self.handleError(
                        SkillError.permissionDenied(.location)
                    )
                }
            }
        }
    }

    private func setManager(_ manager: CLLocationManager) {
        self.manager = manager
    }

    fileprivate func handleLocation(_ location: CLLocation) {
        continuation?.resume(returning: location)
        continuation = nil
    }

    fileprivate func handleError(_ error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }

    fileprivate func handleAuthorizationChange(_ status: CLAuthorizationStatus) {
        switch status {
        case .authorizedAlways, .authorized:
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                let manager = await self.getManager()
                manager?.requestLocation()
            }
        case .denied, .restricted:
            handleError(SkillError.permissionDenied(.location))
        default:
            break
        }
    }

    private func getManager() -> CLLocationManager? {
        return manager
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationFetcher: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else { return }
        Task {
            await self.handleLocation(location)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task {
            await self.handleError(
                SkillError.executionFailed("Location error: \(error.localizedDescription)")
            )
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task {
            await self.handleAuthorizationChange(manager.authorizationStatus)
        }
    }
}
