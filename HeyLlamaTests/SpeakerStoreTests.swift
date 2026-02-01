import XCTest
@testable import HeyLlama

final class SpeakerStoreTests: XCTestCase {

    var store: SpeakerStore!
    var testDirectory: URL!

    override func setUpWithError() throws {
        // Create temp directory for test isolation
        testDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: testDirectory, withIntermediateDirectories: true)

        store = SpeakerStore(baseDirectory: testDirectory)
    }

    override func tearDownWithError() throws {
        // Clean up test directory
        try? FileManager.default.removeItem(at: testDirectory)
    }

    func testLoadSpeakersReturnsEmptyWhenNoFile() {
        let speakers = store.loadSpeakers()
        XCTAssertTrue(speakers.isEmpty)
    }

    func testSaveAndLoadSpeakers() throws {
        let embedding = SpeakerEmbedding(vector: [1, 2, 3], modelVersion: "1.0")
        let speaker = Speaker(name: "Alice", embedding: embedding)

        try store.saveSpeakers([speaker])
        let loaded = store.loadSpeakers()

        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.name, "Alice")
        XCTAssertEqual(loaded.first?.embedding.vector, [1, 2, 3])
    }

    func testSaveMultipleSpeakers() throws {
        let e1 = SpeakerEmbedding(vector: [1], modelVersion: "1.0")
        let e2 = SpeakerEmbedding(vector: [2], modelVersion: "1.0")
        let speaker1 = Speaker(name: "Alice", embedding: e1)
        let speaker2 = Speaker(name: "Bob", embedding: e2)

        try store.saveSpeakers([speaker1, speaker2])
        let loaded = store.loadSpeakers()

        XCTAssertEqual(loaded.count, 2)
        XCTAssertTrue(loaded.contains(where: { $0.name == "Alice" }))
        XCTAssertTrue(loaded.contains(where: { $0.name == "Bob" }))
    }

    func testSaveOverwritesExisting() throws {
        let e1 = SpeakerEmbedding(vector: [1], modelVersion: "1.0")
        let speaker1 = Speaker(name: "Alice", embedding: e1)

        try store.saveSpeakers([speaker1])

        let e2 = SpeakerEmbedding(vector: [2], modelVersion: "1.0")
        let speaker2 = Speaker(name: "Bob", embedding: e2)

        try store.saveSpeakers([speaker2])

        let loaded = store.loadSpeakers()

        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.name, "Bob")
    }

    func testHasSpeakersReturnsFalseWhenEmpty() {
        XCTAssertFalse(store.hasSpeakers())
    }

    func testHasSpeakersReturnsTrueWhenPopulated() throws {
        let embedding = SpeakerEmbedding(vector: [1], modelVersion: "1.0")
        let speaker = Speaker(name: "Alice", embedding: embedding)

        try store.saveSpeakers([speaker])

        XCTAssertTrue(store.hasSpeakers())
    }

    func testSpeakersFileLocation() {
        let expectedPath = testDirectory.appendingPathComponent("speakers.json")
        XCTAssertEqual(store.speakersFileURL, expectedPath)
    }
}
