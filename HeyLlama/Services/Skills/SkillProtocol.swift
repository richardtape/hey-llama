import Foundation

// MARK: - Skill Protocol

/// Protocol that all skills must conform to.
///
/// Each skill is completely self-contained in a single file with:
/// - Static metadata (id, name, description, permissions)
/// - An `Arguments` type marked `@Generable` for Apple's guided generation
/// - A JSON schema string for OpenAI-compatible providers
/// - Execution logic
///
/// ## Adding a New Skill
///
/// 1. Create a new file in `Services/Skills/` (e.g., `CalendarSkill.swift`)
/// 2. Define a struct conforming to `Skill`
/// 3. Define the `Arguments` struct with `@Generable` (if using Apple Intelligence)
/// 4. Write the matching `argumentsJSONSchema`
/// 5. Implement `execute(arguments:context:)`
/// 6. Add the skill type to `SkillsRegistry.allSkillTypes`
/// 7. Add tests verifying the JSON schema matches the Arguments struct
///
/// See `docs/adding-skills.md` for detailed instructions.
protocol Skill {
    /// Unique identifier (e.g., "weather.forecast")
    static var id: String { get }

    /// Human-readable name (e.g., "Weather Forecast")
    static var name: String { get }

    /// Description for LLM to understand when to use this skill.
    /// This is included in the skills manifest sent to the LLM.
    static var skillDescription: String { get }

    /// System permissions required to run this skill (e.g., [.location])
    static var requiredPermissions: [SkillPermission] { get }

    /// Whether ResponseAgent should synthesize a natural response from this skill's output.
    /// Set to `true` for skills that return data needing conversational formatting.
    /// Set to `false` for skills that already return user-ready text.
    static var includesInResponseAgent: Bool { get }

    /// JSON Schema describing the arguments for OpenAI-compatible providers.
    ///
    /// IMPORTANT: This schema MUST match the `Arguments` struct exactly.
    /// - Same property names
    /// - Same types (string, integer, boolean, array)
    /// - Same required/optional status
    ///
    /// Tests verify this stays in sync. See `SkillSchemaValidatorTests`.
    static var argumentsJSONSchema: String { get }

    /// The arguments type for this skill.
    /// For Apple Intelligence, mark this with `@Generable` in your skill file.
    associatedtype Arguments: Codable

    /// Execute the skill with parsed arguments.
    ///
    /// - Parameters:
    ///   - arguments: Decoded arguments (either from Apple's guided generation or JSON)
    ///   - context: Execution context including speaker info and timestamp
    /// - Returns: Skill result with text response and optional structured data
    func execute(arguments: Arguments, context: SkillContext) async throws -> SkillResult
}

// MARK: - Supporting Types

/// Context passed to skills when they execute
struct SkillContext: Sendable {
    let speaker: Speaker?
    let source: AudioSource
    let timestamp: Date

    init(speaker: Speaker? = nil, source: AudioSource = .localMic, timestamp: Date = Date()) {
        self.speaker = speaker
        self.source = source
        self.timestamp = timestamp
    }
}

/// Result returned by a skill after execution
struct SkillResult {
    let text: String
    let data: [String: Any]?
    let summary: SkillSummary?

    init(text: String, data: [String: Any]? = nil, summary: SkillSummary? = nil) {
        self.text = text
        self.data = data
        self.summary = summary
    }
}

/// Errors that can occur during skill execution
enum SkillError: Error, LocalizedError, Equatable {
    case permissionDenied(SkillPermission)
    case permissionNotRequested(SkillPermission)
    case invalidArguments(String)
    case executionFailed(String)
    case skillNotFound(String)
    case skillDisabled(String)

    var errorDescription: String? {
        switch self {
        case .permissionDenied(let permission):
            return "\(permission.displayName) permission was denied"
        case .permissionNotRequested(let permission):
            return "\(permission.displayName) permission has not been requested"
        case .invalidArguments(let message):
            return "Invalid arguments: \(message)"
        case .executionFailed(let message):
            return "Skill execution failed: \(message)"
        case .skillNotFound(let id):
            return "Skill not found: \(id)"
        case .skillDisabled(let id):
            return "Skill is disabled: \(id)"
        }
    }
}
