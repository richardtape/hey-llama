import XCTest
@testable import HeyLlama

final class ConversationManagerTests: XCTestCase {

    @MainActor
    func testAddTurnAndGetHistory() async {
        let manager = ConversationManager(timeoutMinutes: 5, maxTurns: 10)

        manager.addTurn(role: .user, content: "What's the capital of France?")
        manager.addTurn(role: .assistant, content: "Paris")

        let history = manager.getRecentHistory()
        XCTAssertEqual(history.count, 2)
        XCTAssertEqual(history[0].role, .user)
        XCTAssertEqual(history[0].content, "What's the capital of France?")
        XCTAssertEqual(history[1].role, .assistant)
        XCTAssertEqual(history[1].content, "Paris")
    }

    @MainActor
    func testMaxTurnsLimit() async {
        let manager = ConversationManager(timeoutMinutes: 5, maxTurns: 3)

        manager.addTurn(role: .user, content: "One")
        manager.addTurn(role: .assistant, content: "Two")
        manager.addTurn(role: .user, content: "Three")
        manager.addTurn(role: .assistant, content: "Four")

        let history = manager.getRecentHistory()
        // Should only keep last 3 turns
        XCTAssertEqual(history.count, 3)
        XCTAssertEqual(history[0].content, "Two")
        XCTAssertEqual(history[1].content, "Three")
        XCTAssertEqual(history[2].content, "Four")
    }

    @MainActor
    func testTimeoutPruning() async {
        let manager = ConversationManager(timeoutMinutes: 1, maxTurns: 10)

        // Add a turn with an old timestamp
        let oldTurn = ConversationTurn(
            role: .user,
            content: "Old message",
            timestamp: Date().addingTimeInterval(-120) // 2 minutes ago
        )
        manager.addTurnDirectly(oldTurn)

        // Add a recent turn
        manager.addTurn(role: .user, content: "Recent message")

        let history = manager.getRecentHistory()
        // Old turn should be pruned
        XCTAssertEqual(history.count, 1)
        XCTAssertEqual(history[0].content, "Recent message")
    }

    @MainActor
    func testClearHistory() async {
        let manager = ConversationManager(timeoutMinutes: 5, maxTurns: 10)

        manager.addTurn(role: .user, content: "Hello")
        manager.addTurn(role: .assistant, content: "Hi!")

        manager.clearHistory()

        let history = manager.getRecentHistory()
        XCTAssertTrue(history.isEmpty)
    }

    @MainActor
    func testEmptyHistoryReturnsEmptyArray() async {
        let manager = ConversationManager(timeoutMinutes: 5, maxTurns: 10)
        let history = manager.getRecentHistory()
        XCTAssertTrue(history.isEmpty)
    }

    @MainActor
    func testHasRecentHistory() async {
        let manager = ConversationManager(timeoutMinutes: 5, maxTurns: 10)

        XCTAssertFalse(manager.hasRecentHistory())

        manager.addTurn(role: .user, content: "Hello")
        XCTAssertTrue(manager.hasRecentHistory())

        manager.clearHistory()
        XCTAssertFalse(manager.hasRecentHistory())
    }
}
