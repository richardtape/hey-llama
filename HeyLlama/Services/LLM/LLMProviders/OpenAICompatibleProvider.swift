import Foundation

/// Default system prompt for OpenAI-compatible providers (includes JSON format for skills)
private let openAIDefaultSystemPrompt = """
    You are Llama, a helpful voice assistant. Keep responses concise \
    and conversational, suitable for reading on a small UI display. \
    The current user is {speaker_name}. Be friendly but brief. \
    If the user asks for multiple actions or items, include multiple skill calls.
    """

/// JSON format instructions appended when skills are available
private let openAISkillsJSONInstructions = """
    You must respond with a single JSON object only. Do not wrap in \
    code fences or add extra text. Never put tool call JSON inside \
    the "text" field.
    """

/// OpenAI-compatible API provider (works with Ollama, LM Studio, etc.)
actor OpenAICompatibleProvider: LLMServiceProtocol {
    private let config: OpenAICompatibleConfig
    private let urlSession: URLSession

    var isConfigured: Bool {
        config.isConfigured
    }

    init(config: OpenAICompatibleConfig) {
        self.config = config

        // Configure URLSession with timeout
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = TimeInterval(config.timeoutSeconds)
        configuration.timeoutIntervalForResource = TimeInterval(config.timeoutSeconds)
        self.urlSession = URLSession(configuration: configuration)
    }

    func complete(
        prompt: String,
        context: CommandContext?,
        conversationHistory: [ConversationTurn],
        skillsManifest: String?,
        systemPrompt systemPromptOverride: String?
    ) async throws -> String {
        guard isConfigured else {
            throw LLMError.notConfigured
        }

        // Build the request
        let url = try buildURL()
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Add API key header if provided
        if let apiKey = config.apiKey, !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        // Determine system prompt: use override if provided, otherwise build default
        let speakerName = context?.speaker?.name
        let systemPrompt: String
        if let override = systemPromptOverride {
            systemPrompt = buildSystemPrompt(template: override, speakerName: speakerName)
        } else {
            // Use default, add JSON instructions if skills are available
            var template = openAIDefaultSystemPrompt
            if skillsManifest != nil {
                template += " " + openAISkillsJSONInstructions
            }
            systemPrompt = buildSystemPrompt(template: template, speakerName: speakerName)
        }

        // Build request body
        let body = buildRequestBody(
            systemPrompt: systemPrompt,
            skillsManifest: skillsManifest,
            prompt: prompt,
            conversationHistory: conversationHistory
        )

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        // Make request
        let (data, response) = try await performRequest(request)

        // Check HTTP status
        if let httpResponse = response as? HTTPURLResponse {
            guard (200...299).contains(httpResponse.statusCode) else {
                let message = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw LLMError.apiError(statusCode: httpResponse.statusCode, message: message)
            }
        }

        // Parse response
        return try parseResponse(data)
    }

    // MARK: - Internal Methods (exposed for testing)

    nonisolated func buildURL() throws -> URL {
        let baseURL = config.baseURL.trimmingCharacters(in: .init(charactersIn: "/"))
        guard let url = URL(string: "\(baseURL)/chat/completions") else {
            throw LLMError.notConfigured
        }
        return url
    }

    nonisolated func buildSystemPrompt(template: String, speakerName: String?) -> String {
        let name = speakerName ?? "Guest"
        return template.replacingOccurrences(of: "{speaker_name}", with: name)
    }

    nonisolated func buildRequestBody(
        systemPrompt: String,
        skillsManifest: String?,
        prompt: String,
        conversationHistory: [ConversationTurn]
    ) -> [String: Any] {
        var messages: [[String: String]] = []

        // Build full system message with skills manifest if provided
        var fullSystemPrompt = systemPrompt
        if let manifest = skillsManifest {
            fullSystemPrompt += "\n\n--- SKILLS ---\n\(manifest)"
        }

        // System message
        messages.append([
            "role": "system",
            "content": fullSystemPrompt
        ])

        // Conversation history
        for turn in conversationHistory {
            messages.append([
                "role": turn.role == .user ? "user" : "assistant",
                "content": turn.content
            ])
        }

        // Current user message
        messages.append([
            "role": "user",
            "content": prompt
        ])

        return [
            "model": config.model,
            "messages": messages
        ]
    }

    nonisolated func parseResponse(_ data: Data) throws -> String {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw LLMError.responseParseError("Invalid response structure")
        }

        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func performRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await urlSession.data(for: request)
        } catch let error as URLError {
            switch error.code {
            case .timedOut:
                throw LLMError.timeout
            case .notConnectedToInternet, .networkConnectionLost:
                throw LLMError.networkError("No internet connection")
            default:
                throw LLMError.networkError(error.localizedDescription)
            }
        }
    }
}
