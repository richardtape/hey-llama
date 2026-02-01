// MARK: - Temporarily disabled due to FluidAudio malloc bug
// The tests themselves pass, but FluidAudio causes a malloc double-free
// when this test suite runs. This appears to be a bug in FluidAudio's
// static initialization that conflicts with XCTest.
// Re-enable once FluidAudio fixes this issue.

#if ENABLE_MODEL_TESTS

import XCTest
@testable import HeyLlama

final class CommandTests: XCTestCase {

    func testCommandInit() {
        let command = Command(
            rawText: "Hey Llama what time is it",
            commandText: "what time is it",
            source: .localMic,
            confidence: 0.95
        )

        XCTAssertEqual(command.rawText, "Hey Llama what time is it")
        XCTAssertEqual(command.commandText, "what time is it")
        XCTAssertEqual(command.source, .localMic)
        XCTAssertEqual(command.confidence, 0.95)
        XCTAssertNil(command.speaker)
    }

    func testCommandWithSpeaker() {
        let speaker = Speaker(id: UUID(), name: "Alice", embeddings: [])
        let command = Command(
            rawText: "Hey Llama hello",
            commandText: "hello",
            speaker: speaker,
            source: .localMic,
            confidence: 0.9
        )

        XCTAssertEqual(command.speaker?.name, "Alice")
    }

    func testCommandTimestampIsRecent() {
        let before = Date()
        let command = Command(
            rawText: "test",
            commandText: "test",
            source: .localMic,
            confidence: 1.0
        )
        let after = Date()

        XCTAssertGreaterThanOrEqual(command.timestamp, before)
        XCTAssertLessThanOrEqual(command.timestamp, after)
    }

    func testCommandFromSatellite() {
        let command = Command(
            rawText: "Hey Llama lights on",
            commandText: "lights on",
            source: .satellite("bedroom-pi"),
            confidence: 0.88
        )

        XCTAssertEqual(command.source, .satellite("bedroom-pi"))
    }

    func testConversationTurnInit() {
        let turn = ConversationTurn(role: .user, content: "What time is it?")

        XCTAssertEqual(turn.role, .user)
        XCTAssertEqual(turn.content, "What time is it?")
    }

    func testConversationTurnRoles() {
        let userTurn = ConversationTurn(role: .user, content: "Hello")
        let assistantTurn = ConversationTurn(role: .assistant, content: "Hi there!")

        XCTAssertEqual(userTurn.role, .user)
        XCTAssertEqual(assistantTurn.role, .assistant)
    }

    func testCommandContextInit() {
        let context = CommandContext(
            command: "what time is it",
            source: .localMic
        )

        XCTAssertEqual(context.command, "what time is it")
        XCTAssertEqual(context.source, .localMic)
        XCTAssertNil(context.speaker)
        XCTAssertNil(context.conversationHistory)
    }

    func testCommandContextWithHistory() {
        let history = [
            ConversationTurn(role: .user, content: "Hello"),
            ConversationTurn(role: .assistant, content: "Hi!")
        ]

        let context = CommandContext(
            command: "How are you?",
            source: .localMic,
            conversationHistory: history
        )

        XCTAssertEqual(context.conversationHistory?.count, 2)
    }
}

#endif
