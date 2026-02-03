import Foundation

struct ResponseAgent {
    static func buildPrompt(
        userRequest: String,
        speakerName: String?,
        summaries: [SkillSummary]
    ) -> String {
        var prompt = "You are a helpful voice assistant. "
        prompt += "Generate a natural, conversational response based on the skill results below.\n\n"

        if let name = speakerName {
            prompt += "The user's name is \(name).\n\n"
        }

        prompt += "User request: \(userRequest)\n\n"

        prompt += "Skill results:\n"
        for summary in summaries {
            prompt += "- \(summary.skillId): \(summary.summary)\n"
        }

        prompt += "\nRespond naturally and concisely. Do not mention skill IDs or technical details."

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
            speakerName: speakerName,
            summaries: summaries
        )
        return try await llmService.complete(prompt: prompt, context: nil)
    }
}
