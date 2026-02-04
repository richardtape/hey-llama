import Foundation
import EventKit

// MARK: - Arguments

/// Arguments for the reminders add item skill.
///
/// IMPORTANT: When modifying this struct, you MUST update `argumentsJSONSchema`
/// to match. Run `RemindersAddItemSkillTests.testArgumentsMatchJSONSchema` to verify.
struct RemindersAddItemArguments: Codable {
    /// The name of the Reminders list to add to
    let listName: String

    /// The item/reminder to add
    let itemName: String

    /// Optional notes for the reminder
    let notes: String?

    /// Optional due date in ISO8601 format
    let dueDateISO8601: String?
}

// MARK: - Skill Definition

/// Skill to add items to Apple Reminders lists.
struct RemindersAddItemSkill: Skill {

    // MARK: - Skill Metadata

    static let id = "reminders.add_item"
    static let name = "Add Reminder"
    static let skillDescription = "Add an item to a Reminders list (e.g., 'add milk to the groceries list'). If the user asks to add multiple items, call this skill once per item."
    static let requiredPermissions: [SkillPermission] = [.reminders]
    static let includesInResponseAgent = true

    // MARK: - Arguments Type Alias

    typealias Arguments = RemindersAddItemArguments

    // MARK: - JSON Schema

    /// JSON Schema for OpenAI-compatible providers.
    ///
    /// IMPORTANT: This schema MUST match the `Arguments` struct above.
    static let argumentsJSONSchema = """
        {
            "type": "object",
            "properties": {
                "listName": {
                    "type": "string",
                    "description": "The name of the Reminders list to add to"
                },
                "itemName": {
                    "type": "string",
                "description": "The item/reminder to add (single item only). If the user lists multiple items, make multiple calls."
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

    // MARK: - Execution

    func execute(arguments: Arguments, context: SkillContext) async throws -> SkillResult {
        // Check permission
        var status = Permissions.checkRemindersStatus()
        if status == .undetermined {
            let granted = await Permissions.requestRemindersAccess()
            status = granted ? .granted : .denied
        }
        guard status == .granted else {
            throw SkillError.permissionDenied(.reminders)
        }

        let eventStore = EKEventStore()

        // Find the target list
        let lookup = RemindersHelpers.lookupReminderList(
            named: arguments.listName,
            in: eventStore
        )
        guard let targetCalendar = lookup.exactMatch else {
            let message = RemindersHelpers.listNotFoundMessage(
                requestedName: arguments.listName,
                closestMatch: lookup.closestMatchName,
                availableNames: lookup.availableNames
            )
            let summary = SkillSummary(
                skillId: Self.id,
                status: .failed,
                summary: message,
                details: [
                    "listName": arguments.listName,
                    "closestList": lookup.closestMatchName ?? "",
                    "availableLists": lookup.availableNames
                ]
            )
            var data: [String: Any] = [
                "listName": arguments.listName,
                "closestList": lookup.closestMatchName ?? "",
                "availableLists": lookup.availableNames
            ]
            if let closest = lookup.closestMatchName {
                var args: [String: Any] = [
                    "listName": closest,
                    "itemName": arguments.itemName
                ]
                if let notes = arguments.notes {
                    args["notes"] = notes
                }
                if let dueDate = arguments.dueDateISO8601 {
                    args["dueDateISO8601"] = dueDate
                }
                data["confirmationType"] = "yes_no"
                data["pendingAction"] = [
                    "skillId": Self.id,
                    "arguments": args,
                    "prompt": message
                ]
            }
            return SkillResult(text: message, data: data, summary: summary)
        }

        // Create the reminder
        let reminder = EKReminder(eventStore: eventStore)
        reminder.title = arguments.itemName
        reminder.calendar = targetCalendar

        if let notes = arguments.notes {
            reminder.notes = notes
        }

        if let dueDateString = arguments.dueDateISO8601 {
            reminder.dueDateComponents = RemindersHelpers.parseDueDateISO8601(dueDateString)
        }

        // Save the reminder
        do {
            try eventStore.save(reminder, commit: true)
        } catch {
            throw SkillError.executionFailed("Failed to save reminder: \(error.localizedDescription)")
        }

        // Build response
        var response = "Added '\(arguments.itemName)' to your \(targetCalendar.title) list"
        if arguments.notes != nil {
            response += " with notes"
        }
        if arguments.dueDateISO8601 != nil {
            response += " with a due date"
        }
        response += "."

        let summary = SkillSummary(
            skillId: Self.id,
            status: .success,
            summary: response,
            details: [
                "listName": targetCalendar.title,
                "itemName": arguments.itemName,
                "reminderId": reminder.calendarItemIdentifier
            ]
        )

        return SkillResult(
            text: response,
            data: [
                "listName": targetCalendar.title,
                "itemName": arguments.itemName,
                "reminderId": reminder.calendarItemIdentifier
            ],
            summary: summary
        )
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
}
