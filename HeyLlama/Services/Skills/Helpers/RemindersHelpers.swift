import EventKit
import Foundation

enum RemindersHelpers {
    static func findReminderList(named name: String, in eventStore: EKEventStore) throws -> EKCalendar {
        let calendars = eventStore.calendars(for: .reminder)
        if let target = calendars.first(where: {
            $0.title.localizedCaseInsensitiveCompare(name) == .orderedSame
        }) {
            return target
        }

        let availableLists = calendars.map { $0.title }.joined(separator: ", ")
        throw SkillError.executionFailed(
            "Could not find a Reminders list named '\(name)'. " +
            "Available lists: \(availableLists.isEmpty ? "none" : availableLists)"
        )
    }

    static func parseDueDateISO8601(_ dueDateString: String) -> DateComponents? {
        let formatter = ISO8601DateFormatter()
        guard let dueDate = formatter.date(from: dueDateString) else {
            return nil
        }
        return Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: dueDate)
    }
}
