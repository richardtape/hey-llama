import Foundation

/// Manages conversation history with time-based windowing.
/// Designed to be used from @MainActor context (AssistantCoordinator).
@MainActor
final class ConversationManager {
    private var turns: [ConversationTurn] = []
    private var pendingConfirmation: PendingConfirmation?

    private let timeoutMinutes: Int
    private let maxTurns: Int
    private let followUpWindowSeconds: Int
    private var followUpLastActivityAt: Date?

    init(timeoutMinutes: Int = 5, maxTurns: Int = 10, followUpWindowSeconds: Int = 15) {
        self.timeoutMinutes = timeoutMinutes
        self.maxTurns = maxTurns
        self.followUpWindowSeconds = followUpWindowSeconds
    }

    /// Add a new conversation turn
    func addTurn(role: ConversationRole, content: String) {
        let turn = ConversationTurn(role: role, content: content)
        addTurnDirectly(turn)
    }

    /// Add a turn directly (used for testing with custom timestamps)
    func addTurnDirectly(_ turn: ConversationTurn) {
        turns.append(turn)
        pruneOldTurns()
    }

    /// Get recent conversation history within the time window
    func getRecentHistory() -> [ConversationTurn] {
        pruneOldTurns()
        return turns
    }

    /// Check if there's any recent conversation history
    func hasRecentHistory() -> Bool {
        pruneOldTurns()
        return !turns.isEmpty
    }

    /// Clear all conversation history
    func clearHistory() {
        turns.removeAll()
    }

    // MARK: - Follow-up window

    func startFollowUpWindow() {
        guard followUpWindowSeconds > 0 else {
            return
        }
        followUpLastActivityAt = Date()
    }

    func extendFollowUpWindow() {
        startFollowUpWindow()
    }

    func endFollowUpWindow() {
        followUpLastActivityAt = nil
    }

    func isFollowUpActive() -> Bool {
        guard followUpWindowSeconds > 0, let lastActivity = followUpLastActivityAt else {
            return false
        }

        return Date().timeIntervalSince(lastActivity) <= Double(followUpWindowSeconds)
    }

    // MARK: - Pending Confirmations

    func setPendingConfirmation(_ pending: PendingConfirmation) {
        pendingConfirmation = pending
        startFollowUpWindow()
    }

    func getPendingConfirmation() -> PendingConfirmation? {
        guard let pending = pendingConfirmation else {
            return nil
        }
        if Date() > pending.expiresAt {
            pendingConfirmation = nil
            return nil
        }
        return pending
    }

    func clearPendingConfirmation() {
        pendingConfirmation = nil
    }

    func pendingConfirmationExpiryDate() -> Date {
        Date().addingTimeInterval(Double(followUpWindowSeconds))
    }

    /// Prune turns that are older than the timeout or exceed max turns
    private func pruneOldTurns() {
        let cutoff = Date().addingTimeInterval(-Double(timeoutMinutes * 60))

        // Remove turns older than timeout
        turns = turns.filter { $0.timestamp > cutoff }

        // Keep only the most recent maxTurns
        if turns.count > maxTurns {
            turns = Array(turns.suffix(maxTurns))
        }
    }
}
