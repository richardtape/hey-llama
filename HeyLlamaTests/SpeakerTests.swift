import XCTest
@testable import HeyLlama

final class SpeakerTests: XCTestCase {

    func testSpeakerInit() {
        let embedding = SpeakerEmbedding(vector: [1, 2, 3], modelVersion: "1.0")
        let speaker = Speaker(name: "Alice", embedding: embedding)

        XCTAssertEqual(speaker.name, "Alice")
        XCTAssertEqual(speaker.embedding.vector, [1, 2, 3])
        XCTAssertNotNil(speaker.id)
        XCTAssertNotNil(speaker.enrolledAt)
    }

    func testSpeakerMetadataDefaults() {
        let embedding = SpeakerEmbedding(vector: [1], modelVersion: "1.0")
        let speaker = Speaker(name: "Bob", embedding: embedding)

        XCTAssertEqual(speaker.metadata.commandCount, 0)
        XCTAssertNil(speaker.metadata.lastSeenAt)
        XCTAssertEqual(speaker.metadata.preferredResponseMode, .speaker)
    }

    func testSpeakerMetadataUpdate() {
        let embedding = SpeakerEmbedding(vector: [1], modelVersion: "1.0")
        var speaker = Speaker(name: "Carol", embedding: embedding)

        speaker.metadata.commandCount = 5
        speaker.metadata.lastSeenAt = Date()

        XCTAssertEqual(speaker.metadata.commandCount, 5)
        XCTAssertNotNil(speaker.metadata.lastSeenAt)
    }

    func testSpeakerCodable() throws {
        let embedding = SpeakerEmbedding(vector: [1.5, 2.5], modelVersion: "test-v1")
        let original = Speaker(name: "Dave", embedding: embedding)

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(Speaker.self, from: data)

        XCTAssertEqual(original.id, decoded.id)
        XCTAssertEqual(original.name, decoded.name)
        XCTAssertEqual(original.embedding, decoded.embedding)
    }

    func testSpeakerEquatable() {
        let embedding = SpeakerEmbedding(vector: [1], modelVersion: "1.0")
        let speaker1 = Speaker(name: "Eve", embedding: embedding)
        let speaker2 = speaker1 // Same reference
        let speaker3 = Speaker(name: "Eve", embedding: embedding) // Different ID

        XCTAssertEqual(speaker1, speaker2)
        XCTAssertNotEqual(speaker1, speaker3) // Different UUIDs
    }

    func testSpeakerIdentifiable() {
        let embedding = SpeakerEmbedding(vector: [1], modelVersion: "1.0")
        let speaker = Speaker(name: "Frank", embedding: embedding)

        // id should be accessible for SwiftUI List
        XCTAssertNotNil(speaker.id)
    }

    func testResponseModes() {
        XCTAssertEqual(ResponseMode.speaker.rawValue, "speaker")
        XCTAssertEqual(ResponseMode.api.rawValue, "api")
        XCTAssertEqual(ResponseMode.both.rawValue, "both")
    }
}
