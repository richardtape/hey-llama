import Foundation

/// Errors that can occur when parsing LLM action plans
enum LLMActionPlanError: Error, LocalizedError, Equatable {
    case invalidJSON
    case missingType
    case unknownType(String)
    case missingField(String)
    case invalidField(String, String)

    var errorDescription: String? {
        switch self {
        case .invalidJSON:
            return "Invalid JSON response from LLM"
        case .missingType:
            return "Missing 'type' field in action plan"
        case .unknownType(let type):
            return "Unknown action type: \(type)"
        case .missingField(let field):
            return "Missing required field: \(field)"
        case .invalidField(let field, let reason):
            return "Invalid field '\(field)': \(reason)"
        }
    }
}

/// A skill call requested by the LLM
struct SkillCall: Sendable {
    let skillId: String
    let arguments: [String: Any]

    /// Convert arguments back to JSON string for passing to skill
    func argumentsAsJSON() throws -> String {
        let data = try JSONSerialization.data(withJSONObject: arguments, options: [])
        guard let string = String(data: data, encoding: .utf8) else {
            throw LLMActionPlanError.invalidJSON
        }
        return string
    }
}

// Make SkillCall work with Sendable by using @unchecked since [String: Any] isn't inherently Sendable
// but we ensure thread safety through proper usage patterns
extension SkillCall: @unchecked Sendable {}

/// The action plan returned by the LLM
enum LLMActionPlan: Sendable {
    /// LLM wants to respond with text directly
    case respond(text: String)

    /// LLM wants to call one or more skills
    case callSkills(calls: [SkillCall])

    /// Parse an action plan from JSON string
    static func parse(from jsonString: String) throws -> LLMActionPlan {
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw LLMActionPlanError.invalidJSON
        }

        guard let type = json["type"] as? String else {
            throw LLMActionPlanError.missingType
        }

        switch type {
        case "respond":
            guard let text = json["text"] as? String else {
                throw LLMActionPlanError.missingField("text")
            }
            return .respond(text: text)

        case "call_skills":
            guard let callsArray = json["calls"] as? [[String: Any]] else {
                throw LLMActionPlanError.missingField("calls")
            }

            let calls = try callsArray.map { callDict -> SkillCall in
                guard let skillId = callDict["skillId"] as? String else {
                    throw LLMActionPlanError.missingField("skillId")
                }
                let arguments = callDict["arguments"] as? [String: Any] ?? [:]
                return SkillCall(skillId: skillId, arguments: arguments)
            }

            return .callSkills(calls: calls)

        default:
            throw LLMActionPlanError.unknownType(type)
        }
    }
}
