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
        let calendars = eventStore.calendars(for: .reminder)
        guard let targetCalendar = calendars.first(where: {
            $0.title.localizedCaseInsensitiveCompare(args.listName) == .orderedSame
        }) else {
            let availableLists = calendars.map { $0.title }.joined(separator: ", ")
            throw SkillError.executionFailed(
                "Could not find a Reminders list named '\(args.listName)'. " +
                "Available lists: \(availableLists.isEmpty ? "none" : availableLists)"
            )
        }

        // Create the reminder
        let reminder = EKReminder(eventStore: eventStore)
        reminder.title = args.itemName
        reminder.calendar = targetCalendar

        if let notes = args.notes {
            reminder.notes = notes
        }

        if let dueDateString = args.dueDateISO8601 {
            let formatter = ISO8601DateFormatter()
            if let dueDate = formatter.date(from: dueDateString) {
                reminder.dueDateComponents = Calendar.current.dateComponents(
                    [.year, .month, .day, .hour, .minute],
                    from: dueDate
                )
            }
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

        return SkillResult(
            text: response,
            data: [
                "listName": targetCalendar.title,
                "itemName": args.itemName,
                "reminderId": reminder.calendarItemIdentifier
            ]
        )
    }
}
