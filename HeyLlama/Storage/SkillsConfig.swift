import Foundation

/// Configuration for the skills system
struct SkillsConfig: Codable, Equatable, Sendable {
    /// IDs of skills that are enabled
    var enabledSkillIds: [String]

    init(enabledSkillIds: [String] = []) {
        self.enabledSkillIds = enabledSkillIds
    }

    /// Check if a specific skill is enabled
    func isSkillEnabled(_ skillId: String) -> Bool {
        enabledSkillIds.contains(skillId)
    }
}
