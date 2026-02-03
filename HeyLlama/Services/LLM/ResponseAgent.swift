import Foundation

/// System prompt for the Response Agent - focused on natural conversational output
private let responseAgentSystemPrompt = """
    You are Llama, a friendly voice assistant. Your job is to take skill results \
    and turn them into natural, conversational responses. Be concise and warm. \
    The current user is {speaker_name}. \
    IMPORTANT: Respond with plain text only. Do NOT use JSON format. \
    Do NOT wrap your response in code blocks or quotes.
    """

struct ResponseAgent {
    static func buildPrompt(
        userRequest: String,
        summaries: [SkillSummary]
    ) -> String {
        var prompt = "User request: \(userRequest)\n\n"

        prompt += "Skill results:\n"
        for summary in summaries {
            prompt += "- \(summary.skillId): \(summary.summary)\n"
        }

        prompt += "\nGenerate a natural response based on these results."

        return prompt
    }

    static func generateResponse(
        userRequest: String,
        speakerName: String?,
        summaries: [SkillSummary],
        llmService: any LLMServiceProtocol
    ) async throws -> String {
        let prompt = buildPrompt(
            userRequest: userRequest,
            summaries: summaries
        )

        // Build system prompt with speaker name
        let name = speakerName ?? "Guest"
        let systemPrompt = responseAgentSystemPrompt.replacingOccurrences(of: "{speaker_name}", with: name)

        print("[ResponseAgent] System prompt: \(systemPrompt)")
        print("[ResponseAgent] User prompt: \(prompt)")

        let response = try await llmService.complete(
            prompt: prompt,
            context: nil,
            conversationHistory: [],
            skillsManifest: nil,
            systemPrompt: systemPrompt
        )
        print("[ResponseAgent] Raw LLM response: \(response)")

        // If LLM still returns JSON, try to extract the text (fallback)
        let cleanedResponse = extractTextFromResponse(response)
        print("[ResponseAgent] Final response: \(cleanedResponse)")

        return cleanedResponse
    }

    /// Extract plain text from response, handling JSON if LLM returns it anyway
    private static func extractTextFromResponse(_ response: String) -> String {
        let trimmed = response.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove markdown code blocks if present
        var cleaned = trimmed
        if cleaned.hasPrefix("```json") {
            cleaned = String(cleaned.dropFirst(7))
        } else if cleaned.hasPrefix("```") {
            cleaned = String(cleaned.dropFirst(3))
        }
        if cleaned.hasSuffix("```") {
            cleaned = String(cleaned.dropLast(3))
        }
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

        // Try to parse as JSON and extract text field
        if cleaned.hasPrefix("{"),
           let data = cleaned.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let text = json["text"] as? String {
            return text
        }

        return response
    }
}
