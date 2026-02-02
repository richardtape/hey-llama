import Foundation

/// Permissions that skills may require
enum SkillPermission: String, Codable, CaseIterable, Sendable {
    case reminders = "reminders"
    case location = "location"

    var displayName: String {
        switch self {
        case .reminders:
            return "Reminders"
        case .location:
            return "Location"
        }
    }

    var description: String {
        switch self {
        case .reminders:
            return "Access to create and manage reminders"
        case .location:
            return "Access to your location for weather forecasts"
        }
    }

    var systemSettingsKey: String {
        switch self {
        case .reminders:
            return "Privacy_Reminders"
        case .location:
            return "Privacy_LocationServices"
        }
    }
}
