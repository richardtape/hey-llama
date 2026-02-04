import Foundation

/// Enum-based registry to avoid protocol existential issues
enum RegisteredSkill: CaseIterable, Sendable {
    case weatherForecast
    case remindersAddItem
    case remindersRemoveItem
    case remindersCompleteItem
    case remindersReadItems

    var id: String {
        switch self {
        case .weatherForecast: return "weather.forecast"
        case .remindersAddItem: return "reminders.add_item"
        case .remindersRemoveItem: return "reminders.remove_item"
        case .remindersCompleteItem: return "reminders.complete_item"
        case .remindersReadItems: return "reminders.read_items"
        }
    }

    var name: String {
        switch self {
        case .weatherForecast: return "Weather Forecast"
        case .remindersAddItem: return "Add Reminder"
        case .remindersRemoveItem: return "Remove Reminder"
        case .remindersCompleteItem: return "Complete Reminder"
        case .remindersReadItems: return "Read Reminders"
        }
    }

    var skillDescription: String {
        switch self {
        case .weatherForecast:
            return "Get the weather forecast for today, tomorrow, or the next 7 days"
        case .remindersAddItem:
            return "Add an item to a Reminders list (e.g., 'add milk to the groceries list')"
        case .remindersRemoveItem:
            return "Remove an item from a Reminders list (e.g., 'remove milk from the groceries list')"
        case .remindersCompleteItem:
            return "Mark an item as complete in a Reminders list (e.g., 'mark milk complete in the groceries list')"
        case .remindersReadItems:
            return "Read items from a Reminders list (e.g., 'what's on my groceries list')"
        }
    }

    var requiredPermissions: [SkillPermission] {
        switch self {
        case .weatherForecast: return [.location]
        case .remindersAddItem: return [.reminders]
        case .remindersRemoveItem: return [.reminders]
        case .remindersCompleteItem: return [.reminders]
        case .remindersReadItems: return [.reminders]
        }
    }

    var includesInResponseAgent: Bool {
        switch self {
        case .weatherForecast: return true
        case .remindersAddItem: return true
        case .remindersRemoveItem: return true
        case .remindersCompleteItem: return true
        case .remindersReadItems: return true
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
        case .remindersRemoveItem:
            return """
            {
                "type": "object",
                "properties": {
                    "listName": {
                        "type": "string",
                        "description": "The name of the Reminders list to remove from"
                    },
                    "itemName": {
                        "type": "string",
                        "description": "The item/reminder to remove"
                    }
                },
                "required": ["listName", "itemName"]
            }
            """
        case .remindersCompleteItem:
            return """
            {
                "type": "object",
                "properties": {
                    "listName": {
                        "type": "string",
                        "description": "The name of the Reminders list to mark complete in"
                    },
                    "itemName": {
                        "type": "string",
                        "description": "The item/reminder to mark complete"
                    }
                },
                "required": ["listName", "itemName"]
            }
            """
        case .remindersReadItems:
            return """
            {
                "type": "object",
                "properties": {
                    "listName": {
                        "type": "string",
                        "description": "The name of the Reminders list to read from"
                    },
                    "status": {
                        "type": "string",
                        "enum": ["incomplete", "completed"],
                        "description": "Optional filter. Use 'completed' only if the user explicitly asks for completed items. Default is incomplete."
                    }
                },
                "required": ["listName"]
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
        case .remindersRemoveItem:
            return try await RemindersRemoveItemSkill().run(argumentsJSON: argumentsJSON, context: context)
        case .remindersCompleteItem:
            return try await RemindersCompleteItemSkill().run(argumentsJSON: argumentsJSON, context: context)
        case .remindersReadItems:
            return try await RemindersReadItemsSkill().run(argumentsJSON: argumentsJSON, context: context)
        }
    }
}

// MARK: - Skills Registry

/// Central registry for all available skills.
///
/// ## Adding a New Skill
///
/// 1. Create your skill file conforming to `Skill` protocol
/// 2. Add the skill type to `allSkillTypes` below
/// 3. Add a case in `AppleIntelligenceProvider.makeToolForSkill()`
/// 4. Add tests verifying schema matches struct
///
/// See `docs/adding-skills.md` for detailed instructions.
struct SkillsRegistry {

    // MARK: - Registered Skills

    /// All skill types registered in the system.
    ///
    /// To register a new skill, add its type here.
    /// Order determines display order in settings UI.
    static let allSkillTypes: [any Skill.Type] = [
        WeatherForecastSkill.self,
        RemindersAddItemSkill.self,
        RemindersRemoveItemSkill.self,
        RemindersCompleteItemSkill.self,
        RemindersReadItemsSkill.self,
        // Future skills:
        // CalendarSkill.self,
        // MessagesSkill.self,
        // EmailSkill.self,
    ]

    // MARK: - Instance State

    var enabledSkillIds: Set<String>

    init(config: SkillsConfig = SkillsConfig()) {
        self.enabledSkillIds = Set(config.enabledSkillIds)
    }

    // MARK: - Skill Type Queries (New API)

    /// All registered skill types
    var allSkillTypes: [any Skill.Type] {
        Self.allSkillTypes
    }

    /// Skill types that are currently enabled
    var enabledSkillTypes: [any Skill.Type] {
        Self.allSkillTypes.filter { enabledSkillIds.contains($0.id) }
    }

    /// Get a skill type by its ID
    static func skillType(withId id: String) -> (any Skill.Type)? {
        allSkillTypes.first { $0.id == id }
    }

    // MARK: - Legacy API (RegisteredSkill compatibility)

    /// All skills registered in the system (legacy)
    var allSkills: [RegisteredSkill] {
        RegisteredSkill.allCases
    }

    /// Skills that are currently enabled based on config (legacy)
    var enabledSkills: [RegisteredSkill] {
        RegisteredSkill.allCases.filter { enabledSkillIds.contains($0.id) }
    }

    /// Get a skill by its ID (legacy)
    func skill(withId id: String) -> RegisteredSkill? {
        RegisteredSkill.allCases.first { $0.id == id }
    }

    // MARK: - Common API

    /// Check if a skill is enabled
    func isSkillEnabled(_ skillId: String) -> Bool {
        enabledSkillIds.contains(skillId)
    }

    /// Update the skills configuration
    mutating func updateConfig(_ newConfig: SkillsConfig) {
        enabledSkillIds = Set(newConfig.enabledSkillIds)
    }

    // MARK: - Manifest Generation

    /// Generate a manifest of enabled skills for LLM prompt injection.
    ///
    /// For OpenAI-compatible providers, this includes the JSON schema for each skill.
    func generateSkillsManifest() -> String {
        let enabled = enabledSkillTypes

        guard !enabled.isEmpty else {
            return "No skills are currently enabled. Respond with a helpful text message."
        }

        var manifest = "You have access to the following skills (tools). "
        manifest += "You must respond with a single JSON object only. Do not wrap in code fences. "
        manifest += "Do not add extra text before or after the JSON. "
        manifest += "To use a skill, respond with JSON in the format: "
        manifest += "{\"type\":\"call_skills\",\"calls\":[{\"skillId\":\"<id>\",\"arguments\":{...}}]}\n"
        manifest += "If a user asks to perform multiple actions or add multiple items, include multiple calls in the \"calls\" array.\n"
        manifest += "To respond with text only, use: {\"type\":\"respond\",\"text\":\"<your response>\"}\n"
        manifest += "Never put tool call JSON inside the \"text\" field.\n\n"
        manifest += "Available skills:\n\n"

        for skillType in enabled {
            manifest += "---\n"
            manifest += "ID: \(skillType.id)\n"
            manifest += "Name: \(skillType.name)\n"
            manifest += "Description: \(skillType.skillDescription)\n"
            manifest += "Arguments schema:\n\(skillType.argumentsJSONSchema)\n\n"
        }

        manifest += "---\n"
        manifest += "IMPORTANT: Always respond with valid JSON. Choose 'respond' for conversational "
        manifest += "replies or 'call_skills' when the user's request matches an available skill.\n"

        return manifest
    }

    // MARK: - Skill Execution

    /// Execute a skill by ID with JSON arguments.
    ///
    /// This is used by AssistantCoordinator to run skills from LLMActionPlan.
    func executeSkill(
        skillId: String,
        argumentsJSON: String,
        context: SkillContext
    ) async throws -> SkillResult {
        guard let skillType = Self.skillType(withId: skillId) else {
            throw SkillError.skillNotFound(skillId)
        }

        guard isSkillEnabled(skillId) else {
            throw SkillError.skillDisabled(skillId)
        }

        // Execute using the skill type - must switch on known types
        // because we can't dynamically instantiate associated types
        switch skillType {
        case is WeatherForecastSkill.Type:
            let args = try JSONDecoder().decode(
                WeatherForecastArguments.self,
                from: argumentsJSON.data(using: .utf8)!
            )
            return try await WeatherForecastSkill().execute(arguments: args, context: context)

        case is RemindersAddItemSkill.Type:
            let args = try JSONDecoder().decode(
                RemindersAddItemArguments.self,
                from: argumentsJSON.data(using: .utf8)!
            )
            return try await RemindersAddItemSkill().execute(arguments: args, context: context)

        case is RemindersRemoveItemSkill.Type:
            let args = try JSONDecoder().decode(
                RemindersRemoveItemArguments.self,
                from: argumentsJSON.data(using: .utf8)!
            )
            return try await RemindersRemoveItemSkill().execute(arguments: args, context: context)

        case is RemindersCompleteItemSkill.Type:
            let args = try JSONDecoder().decode(
                RemindersCompleteItemArguments.self,
                from: argumentsJSON.data(using: .utf8)!
            )
            return try await RemindersCompleteItemSkill().execute(arguments: args, context: context)

        case is RemindersReadItemsSkill.Type:
            let args = try JSONDecoder().decode(
                RemindersReadItemsArguments.self,
                from: argumentsJSON.data(using: .utf8)!
            )
            return try await RemindersReadItemsSkill().execute(arguments: args, context: context)

        default:
            throw SkillError.skillNotFound(skillId)
        }
    }
}
