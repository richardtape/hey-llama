import Foundation
import EventKit

/// Skill to add items to Reminders lists
struct RemindersAddItemSkill {

    // MARK: - Argument Types

    struct Arguments: Codable {
        let listName: String
        let itemName: String
        let notes: String?
        let dueDateISO8601: String?
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
        let targetCalendar = try RemindersHelpers.findReminderList(
            named: args.listName,
            in: eventStore
        )

        // Create the reminder
        let reminder = EKReminder(eventStore: eventStore)
        reminder.title = args.itemName
        reminder.calendar = targetCalendar

        if let notes = args.notes {
            reminder.notes = notes
        }

        if let dueDateString = args.dueDateISO8601 {
            reminder.dueDateComponents = RemindersHelpers.parseDueDateISO8601(dueDateString)
        }

        // Save the reminder
        do {
            try eventStore.save(reminder, commit: true)
        } catch {
            throw SkillError.executionFailed("Failed to save reminder: \(error.localizedDescription)")
        }

        // Build response
        var response = "Added '\(args.itemName)' to your \(targetCalendar.title) list"
        if let notes = args.notes {
            response += " with notes: \(notes)"
        }
        if args.dueDateISO8601 != nil {
            response += " with a due date"
        }
        response += "."

        let summary = SkillSummary(
            skillId: "reminders.add_item",
            status: .success,
            summary: response,
            details: [
                "listName": targetCalendar.title,
                "itemName": args.itemName,
                "reminderId": reminder.calendarItemIdentifier
            ]
        )

        return SkillResult(
            text: response,
            data: [
                "listName": targetCalendar.title,
                "itemName": args.itemName,
                "reminderId": reminder.calendarItemIdentifier
            ],
            summary: summary
        )
    }
}
