import Foundation
import EventKit

// MARK: - Arguments

/// Arguments for the reminders complete item skill.
///
/// IMPORTANT: When modifying this struct, you MUST update `argumentsJSONSchema`
/// to match. Run `RemindersCompleteItemSkillTests.testArgumentsMatchJSONSchema` to verify.
struct RemindersCompleteItemArguments: Codable {
    /// The name of the Reminders list to mark complete in
    let listName: String

    /// The item/reminder to mark as complete
    let itemName: String
}

// MARK: - Skill Definition

/// Skill to mark items complete in Apple Reminders lists.
struct RemindersCompleteItemSkill: Skill {

    // MARK: - Skill Metadata

    static let id = "reminders.complete_item"
    static let name = "Complete Reminder"
    static let skillDescription = "Mark an item as complete in a Reminders list (e.g., 'mark milk complete in the groceries list'). If the user asks to complete multiple items, call this skill once per item."
    static let requiredPermissions: [SkillPermission] = [.reminders]
    static let includesInResponseAgent = true

    // MARK: - Arguments Type Alias

    typealias Arguments = RemindersCompleteItemArguments

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
                    "description": "The name of the Reminders list to mark complete in"
                },
                "itemName": {
                    "type": "string",
                    "description": "The item/reminder to mark complete (single item only). If the user lists multiple items, make multiple calls."
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
            return SkillResult(text: message, summary: summary)
        }

        let reminders = await RemindersHelpers.fetchReminders(
            in: targetCalendar,
            eventStore: eventStore
        )

        guard !reminders.isEmpty else {
            let message = "Your \(targetCalendar.title) list is empty."
            let summary = SkillSummary(
                skillId: Self.id,
                status: .failed,
                summary: message,
                details: [
                    "listName": targetCalendar.title
                ]
            )
            return SkillResult(text: message, summary: summary)
        }

        let matches = RemindersHelpers.findReminders(
            withTitle: arguments.itemName,
            in: reminders
        )

        guard let reminder = matches.first else {
            let closest = RemindersHelpers.closestReminderTitle(
                to: arguments.itemName,
                in: reminders
            )
            let message = RemindersHelpers.reminderNotFoundMessage(
                requestedTitle: arguments.itemName,
                listName: targetCalendar.title,
                closestMatch: closest
            )
            let summary = SkillSummary(
                skillId: Self.id,
                status: .failed,
                summary: message,
                details: [
                    "listName": targetCalendar.title,
                    "itemName": arguments.itemName,
                    "closestItem": closest ?? ""
                ]
            )
            return SkillResult(text: message, summary: summary)
        }

        var response: String
        if reminder.isCompleted {
            response = "'\(reminder.title)' is already marked complete in your \(targetCalendar.title) list."
        } else {
            reminder.isCompleted = true
            reminder.completionDate = Date()

            do {
                try eventStore.save(reminder, commit: true)
            } catch {
                throw SkillError.executionFailed("Failed to mark reminder complete: \(error.localizedDescription)")
            }

            response = "Marked '\(reminder.title)' as complete in your \(targetCalendar.title) list."
        }

        if matches.count > 1 {
            response += " There are still \(matches.count - 1) more with the same name in that list."
        }

        let summary = SkillSummary(
            skillId: Self.id,
            status: .success,
            summary: response,
            details: [
                "listName": targetCalendar.title,
                "itemName": reminder.title,
                "reminderId": reminder.calendarItemIdentifier,
                "isCompleted": reminder.isCompleted
            ]
        )

        return SkillResult(
            text: response,
            data: [
                "listName": targetCalendar.title,
                "itemName": reminder.title,
                "reminderId": reminder.calendarItemIdentifier,
                "isCompleted": reminder.isCompleted
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
