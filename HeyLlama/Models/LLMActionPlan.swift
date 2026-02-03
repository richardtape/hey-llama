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
        // Strip markdown code fences if present (LLMs often wrap JSON in ```json ... ```)
        let cleanedString = stripMarkdownCodeFences(from: jsonString)
        let candidateJSON = extractFirstJSONObject(from: cleanedString) ?? cleanedString
        
        guard let data = candidateJSON.data(using: .utf8),
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
    
    /// Strip markdown code fences from a string
    /// Handles ```json, ```, and variations with whitespace
    private static func stripMarkdownCodeFences(from string: String) -> String {
        var result = string.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove opening fence (```json, ```JSON, or just ```)
        if result.hasPrefix("```") {
            // Find the end of the first line (the fence line)
            if let newlineIndex = result.firstIndex(of: "\n") {
                result = String(result[result.index(after: newlineIndex)...])
            } else {
                // No newline, just remove the backticks
                result = String(result.dropFirst(3))
            }
        }
        
        // Remove closing fence
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        if result.hasSuffix("```") {
            result = String(result.dropLast(3))
        }
        
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Extract the first top-level JSON object from a string.
    /// This is a conservative fallback when models include extra text.
    private static func extractFirstJSONObject(from string: String) -> String? {
        let characters = Array(string)
        var startIndex: Int?
        var depth = 0
        var inString = false
        var escapeNext = false

        for (index, char) in characters.enumerated() {
            if inString {
                if escapeNext {
                    escapeNext = false
                } else if char == "\\" {
                    escapeNext = true
                } else if char == "\"" {
                    inString = false
                }
                continue
            }

            if char == "\"" {
                inString = true
                continue
            }

            if char == "{" {
                if startIndex == nil {
                    startIndex = index
                }
                depth += 1
                continue
            }

            if char == "}" {
                depth -= 1
                if depth == 0, let start = startIndex {
                    return String(characters[start...index])
                }
            }
        }

        return nil
    }
}
