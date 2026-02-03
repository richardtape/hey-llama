import Foundation

/// Enum-based registry to avoid protocol existential issues
enum RegisteredSkill: CaseIterable, Sendable {
    case weatherForecast
    case remindersAddItem

    var id: String {
        switch self {
        case .weatherForecast: return "weather.forecast"
        case .remindersAddItem: return "reminders.add_item"
        }
    }

    var name: String {
        switch self {
        case .weatherForecast: return "Weather Forecast"
        case .remindersAddItem: return "Add Reminder"
        }
    }

    var skillDescription: String {
        switch self {
        case .weatherForecast:
            return "Get the weather forecast for today, tomorrow, or the next 7 days"
        case .remindersAddItem:
            return "Add an item to a Reminders list (e.g., 'add milk to the groceries list')"
        }
    }

    var requiredPermissions: [SkillPermission] {
        switch self {
        case .weatherForecast: return [.location]
        case .remindersAddItem: return [.reminders]
        }
    }

    var includesInResponseAgent: Bool {
        switch self {
        case .weatherForecast: return true
        case .remindersAddItem: return true
        }
    }

    var argumentSchemaJSON: String {
        switch self {
        case .weatherForecast:
            // NOTE: The location description is intentionally detailed to prevent LLMs from
            // passing the speaker's name as a location. Without this guidance, LLMs often
            // interpret "my weather" as meaning the speaker's name rather than GPS location.
            return """
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
        case .remindersAddItem:
            return """
            {
                "type": "object",
                "properties": {
                    "listName": {
                        "type": "string",
                        "description": "The name of the Reminders list to add to"
                    },
                    "itemName": {
                        "type": "string",
                        "description": "The item/reminder to add"
                    },
                    "notes": {
                        "type": "string",
                        "description": "Optional notes for the reminder"
                    },
                    "dueDateISO8601": {
                        "type": "string",
                        "description": "Optional due date in ISO8601 format"
                    }
                },
                "required": ["listName", "itemName"]
            }
            """
        }
    }

    func run(argumentsJSON: String, context: SkillContext) async throws -> SkillResult {
        switch self {
        case .weatherForecast:
            return try await WeatherForecastSkill().run(argumentsJSON: argumentsJSON, context: context)
        case .remindersAddItem:
            return try await RemindersAddItemSkill().run(argumentsJSON: argumentsJSON, context: context)
        }
    }
}

/// Central registry for all available skills
struct SkillsRegistry {
    var enabledSkillIds: [String]

    init(config: SkillsConfig = SkillsConfig()) {
        self.enabledSkillIds = config.enabledSkillIds
    }

    /// All skills registered in the system
    var allSkills: [RegisteredSkill] {
        RegisteredSkill.allCases
    }

    /// Skills that are currently enabled based on config
    var enabledSkills: [RegisteredSkill] {
        RegisteredSkill.allCases.filter { enabledSkillIds.contains($0.id) }
    }

    /// Get a skill by its ID
    func skill(withId id: String) -> RegisteredSkill? {
        RegisteredSkill.allCases.first { $0.id == id }
    }

    /// Check if a skill is enabled
    func isSkillEnabled(_ skillId: String) -> Bool {
        enabledSkillIds.contains(skillId)
    }

    /// Update the skills configuration
    mutating func updateConfig(_ newConfig: SkillsConfig) {
        enabledSkillIds = newConfig.enabledSkillIds
    }

    /// Generate a manifest of enabled skills for LLM prompt injection
    func generateSkillsManifest() -> String {
        let enabled = enabledSkills

        guard !enabled.isEmpty else {
            return "No skills are currently enabled. Respond with a helpful text message."
        }

        var manifest = "You have access to the following skills (tools). "
        manifest += "You must respond with a single JSON object only. Do not wrap in code fences. "
        manifest += "Do not add extra text before or after the JSON. "
        manifest += "To use a skill, respond with JSON in the format: "
        manifest += "{\"type\":\"call_skills\",\"calls\":[{\"skillId\":\"<id>\",\"arguments\":{...}}]}\n"
        manifest += "To respond with text only, use: {\"type\":\"respond\",\"text\":\"<your response>\"}\n"
        manifest += "Never put tool call JSON inside the \"text\" field.\n\n"
        manifest += "Available skills:\n\n"

        for skill in enabled {
            manifest += "---\n"
            manifest += "ID: \(skill.id)\n"
            manifest += "Name: \(skill.name)\n"
            manifest += "Description: \(skill.skillDescription)\n"
            manifest += "Arguments schema:\n\(skill.argumentSchemaJSON)\n\n"
        }

        manifest += "---\n"
        manifest += "IMPORTANT: Always respond with valid JSON. Choose 'respond' for conversational "
        manifest += "replies or 'call_skills' when the user's request matches an available skill.\n"

        return manifest
    }
}
