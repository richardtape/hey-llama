import EventKit
import Foundation

/// Utilities for working with Apple Reminders via EventKit.
enum RemindersHelpers {

    // MARK: - List Lookup

    struct ListLookupResult {
        let exactMatch: EKCalendar?
        let closestMatchName: String?
        let availableNames: [String]
    }

    /// Find a reminder list by exact (case-insensitive) name and provide helpful suggestions.
    static func lookupReminderList(named name: String, in eventStore: EKEventStore) -> ListLookupResult {
        let calendars = eventStore.calendars(for: .reminder)
        let availableNames = calendars.map { $0.title }

        if let exact = calendars.first(where: {
            $0.title.localizedCaseInsensitiveCompare(name) == .orderedSame
        }) {
            return ListLookupResult(
                exactMatch: exact,
                closestMatchName: nil,
                availableNames: availableNames
            )
        }

        let closestName = bestFuzzyMatchName(for: name, in: availableNames)
        return ListLookupResult(
            exactMatch: nil,
            closestMatchName: closestName,
            availableNames: availableNames
        )
    }

    /// Format a user-facing response when the requested list doesn't exist.
    static func listNotFoundMessage(
        requestedName: String,
        closestMatch: String?,
        availableNames: [String]
    ) -> String {
        var message = "I couldn't find a Reminders list named '\(requestedName)'."
        if let closest = closestMatch {
            message += " Did you mean '\(closest)'?"
        }
        if !availableNames.isEmpty {
            let lists = availableNames.joined(separator: ", ")
            message += " Available lists: \(lists)."
        } else {
            message += " You don't have any Reminders lists yet."
        }
        return message
    }

    /// Existing helper retained for backward compatibility.
    static func findReminderList(named name: String, in eventStore: EKEventStore) throws -> EKCalendar {
        let lookup = lookupReminderList(named: name, in: eventStore)
        if let exact = lookup.exactMatch {
            return exact
        }
        let message = listNotFoundMessage(
            requestedName: name,
            closestMatch: lookup.closestMatchName,
            availableNames: lookup.availableNames
        )
        throw SkillError.executionFailed(message)
    }

    // MARK: - Reminder Fetching

    /// Fetch all reminders in a specific list.
    static func fetchReminders(
        in calendar: EKCalendar,
        eventStore: EKEventStore
    ) async -> [EKReminder] {
        let predicate = eventStore.predicateForReminders(in: [calendar])
        return await withCheckedContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { reminders in
                continuation.resume(returning: reminders ?? [])
            }
        }
    }

    /// Filter reminders by completion status.
    enum CompletionFilter {
        case incomplete
        case completed
        case all
    }

    static func filterReminders(
        _ reminders: [EKReminder],
        by filter: CompletionFilter
    ) -> [EKReminder] {
        switch filter {
        case .all:
            return reminders
        case .completed:
            return reminders.filter { $0.isCompleted }
        case .incomplete:
            return reminders.filter { !$0.isCompleted }
        }
    }

    // MARK: - Reminder Matching

    /// Find reminders by exact (case-insensitive) title.
    static func findReminders(
        withTitle title: String,
        in reminders: [EKReminder]
    ) -> [EKReminder] {
        reminders.filter { reminder in
            reminder.title.localizedCaseInsensitiveCompare(title) == .orderedSame
        }
    }

    /// Suggest the closest reminder title from a list of reminders.
    static func closestReminderTitle(
        to title: String,
        in reminders: [EKReminder]
    ) -> String? {
        let titles = reminders.compactMap { $0.title }
        return bestFuzzyMatchName(for: title, in: titles)
    }

    /// Format a user-facing response when the requested reminder doesn't exist.
    static func reminderNotFoundMessage(
        requestedTitle: String,
        listName: String,
        closestMatch: String?
    ) -> String {
        var message = "I couldn't find an item named '\(requestedTitle)' in your \(listName) list."
        if let closest = closestMatch {
            message += " Did you mean '\(closest)'?"
        }
        return message
    }

    // MARK: - Date Parsing

    static func parseDueDateISO8601(_ dueDateString: String) -> DateComponents? {
        let formatter = ISO8601DateFormatter()
        guard let dueDate = formatter.date(from: dueDateString) else {
            return nil
        }
        return Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: dueDate)
    }

    // MARK: - String Matching

    /// Return the closest fuzzy match name using a lightweight similarity score.
    static func bestFuzzyMatchName(for target: String, in options: [String]) -> String? {
        guard !options.isEmpty else { return nil }
        let normalizedTarget = normalizeString(target)
        var bestOption: String?
        var bestScore = -Double.infinity

        for option in options {
            let normalizedOption = normalizeString(option)
            let score = similarityScore(normalizedTarget, normalizedOption)
            if score > bestScore {
                bestScore = score
                bestOption = option
            }
        }
        return bestOption
    }

    /// Normalize a string for comparison.
    static func normalizeString(_ string: String) -> String {
        let lowered = string.lowercased()
        let allowed = CharacterSet.alphanumerics.union(.whitespaces)
        let filtered = lowered.unicodeScalars.filter { allowed.contains($0) }
        let collapsed = String(filtered)
            .split(separator: " ")
            .joined(separator: " ")
        return collapsed.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Levenshtein-based similarity score (0.0 - 1.0).
    static func similarityScore(_ lhs: String, _ rhs: String) -> Double {
        let lhsChars = Array(lhs)
        let rhsChars = Array(rhs)
        let lhsCount = lhsChars.count
        let rhsCount = rhsChars.count

        if lhsCount == 0 && rhsCount == 0 { return 1.0 }
        if lhsCount == 0 || rhsCount == 0 { return 0.0 }

        var distances = Array(repeating: Array(repeating: 0, count: rhsCount + 1), count: lhsCount + 1)

        for i in 0...lhsCount { distances[i][0] = i }
        for j in 0...rhsCount { distances[0][j] = j }

        for i in 1...lhsCount {
            for j in 1...rhsCount {
                let cost = lhsChars[i - 1] == rhsChars[j - 1] ? 0 : 1
                distances[i][j] = min(
                    distances[i - 1][j] + 1,
                    distances[i][j - 1] + 1,
                    distances[i - 1][j - 1] + cost
                )
            }
        }

        let distance = distances[lhsCount][rhsCount]
        let maxLen = max(lhsCount, rhsCount)
        return 1.0 - (Double(distance) / Double(maxLen))
    }
}
