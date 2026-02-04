import Foundation

/// Represents a deferred skill action waiting on a yes/no/cancel confirmation.
struct PendingConfirmation {
    let skillId: String
    let arguments: [String: Any]
    let prompt: String
    let createdAt: Date
    let expiresAt: Date
    let originUserRequest: String?

    init(
        skillId: String,
        arguments: [String: Any],
        prompt: String,
        createdAt: Date = Date(),
        expiresAt: Date,
        originUserRequest: String? = nil
    ) {
        self.skillId = skillId
        self.arguments = arguments
        self.prompt = prompt
        self.createdAt = createdAt
        self.expiresAt = expiresAt
        self.originUserRequest = originUserRequest
    }

    static func fromSkillResultData(
        _ data: [String: Any],
        defaultExpiry: Date,
        originUserRequest: String?
    ) -> PendingConfirmation? {
        guard let pending = data["pendingAction"] as? [String: Any],
              let skillId = pending["skillId"] as? String,
              let arguments = pending["arguments"] as? [String: Any],
              let prompt = pending["prompt"] as? String else {
            return nil
        }

        return PendingConfirmation(
            skillId: skillId,
            arguments: arguments,
            prompt: prompt,
            expiresAt: defaultExpiry,
            originUserRequest: originUserRequest
        )
    }
}
