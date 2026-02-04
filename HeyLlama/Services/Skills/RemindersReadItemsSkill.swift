import Foundation
import EventKit

// MARK: - Arguments

/// Arguments for the reminders read items skill.
///
/// IMPORTANT: When modifying this struct, you MUST update `argumentsJSONSchema`
/// to match. Run `RemindersReadItemsSkillTests.testArgumentsMatchJSONSchema` to verify.
struct RemindersReadItemsArguments: Codable {
    /// The name of the Reminders list to read from
    let listName: String

    /// Optional status filter: "incomplete" or "completed"
    let status: String?
}

// MARK: - Skill Definition

/// Skill to read items from Apple Reminders lists.
struct RemindersReadItemsSkill: Skill {

    // MARK: - Skill Metadata

    static let id = "reminders.read_items"
    static let name = "Read Reminders"
    static let skillDescription = "Read items from a Reminders list (e.g., 'what's on my groceries list'). By default, read incomplete items only. If the user asks for completed items, set status to 'completed'."
    static let requiredPermissions: [SkillPermission] = [.reminders]
    static let includesInResponseAgent = true

    // MARK: - Arguments Type Alias

    typealias Arguments = RemindersReadItemsArguments

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
                    "listName": closest
                ]
                if let status = arguments.status {
                    args["status"] = status
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

        let reminders = await RemindersHelpers.fetchReminders(
            in: targetCalendar,
            eventStore: eventStore
        )

        let filter: RemindersHelpers.CompletionFilter
        if arguments.status?.lowercased() == "completed" {
            filter = .completed
        } else {
            filter = .incomplete
        }

        let filtered = RemindersHelpers.filterReminders(reminders, by: filter)
        let statusLabel = filter == .completed ? "completed" : "incomplete"

        guard !filtered.isEmpty else {
            let message = "You have no \(statusLabel) items in your \(targetCalendar.title) list."
            let summary = SkillSummary(
                skillId: Self.id,
                status: .success,
                summary: message,
                details: [
                    "listName": targetCalendar.title,
                    "status": statusLabel
                ]
            )
            return SkillResult(text: message, summary: summary)
        }

        let titles = filtered.compactMap { $0.title }
        let joinedTitles = titles.joined(separator: ", ")
        let response = "Here are the \(statusLabel) items in your \(targetCalendar.title) list: \(joinedTitles)."

        let summary = SkillSummary(
            skillId: Self.id,
            status: .success,
            summary: response,
            details: [
                "listName": targetCalendar.title,
                "status": statusLabel,
                "items": titles
            ]
        )

        return SkillResult(
            text: response,
            data: [
                "listName": targetCalendar.title,
                "status": statusLabel,
                "items": titles
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
