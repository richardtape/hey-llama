import XCTest
@testable import HeyLlama

final class SpeakerEmbeddingTests: XCTestCase {

    func testIdenticalVectorsHaveZeroDistance() {
        let embedding1 = SpeakerEmbedding(vector: [1, 0, 0], modelVersion: "1.0")
        let embedding2 = SpeakerEmbedding(vector: [1, 0, 0], modelVersion: "1.0")

        let distance = embedding1.distance(to: embedding2)

        XCTAssertEqual(distance, 0, accuracy: 0.001)
    }

    func testOrthogonalVectorsHaveMaxDistance() {
        let embedding1 = SpeakerEmbedding(vector: [1, 0, 0], modelVersion: "1.0")
        let embedding2 = SpeakerEmbedding(vector: [0, 1, 0], modelVersion: "1.0")

        let distance = embedding1.distance(to: embedding2)

        XCTAssertEqual(distance, 1, accuracy: 0.001)
    }

    func testMismatchedLengthsReturnMaxDistance() {
        let embedding1 = SpeakerEmbedding(vector: [1, 0, 0], modelVersion: "1.0")
        let embedding2 = SpeakerEmbedding(vector: [1, 0], modelVersion: "1.0")

        let distance = embedding1.distance(to: embedding2)

        XCTAssertEqual(distance, 1.0)
    }

    func testPartialSimilarityReturnsExpectedDistance() {
        // [1, 1, 0] and [1, 0, 0] have cos(45°) ≈ 0.707, so distance ≈ 0.29
        let embedding1 = SpeakerEmbedding(vector: [1, 1, 0], modelVersion: "1.0")
        let embedding2 = SpeakerEmbedding(vector: [1, 0, 0], modelVersion: "1.0")

        let distance = embedding1.distance(to: embedding2)

        XCTAssertEqual(distance, 0.29, accuracy: 0.02)
    }

    func testDistanceIsSymmetric() {
        let embedding1 = SpeakerEmbedding(vector: [1, 2, 3], modelVersion: "1.0")
        let embedding2 = SpeakerEmbedding(vector: [4, 5, 6], modelVersion: "1.0")

        let distance1 = embedding1.distance(to: embedding2)
        let distance2 = embedding2.distance(to: embedding1)

        XCTAssertEqual(distance1, distance2, accuracy: 0.0001)
    }

    func testZeroVectorReturnsMaxDistance() {
        let embedding1 = SpeakerEmbedding(vector: [0, 0, 0], modelVersion: "1.0")
        let embedding2 = SpeakerEmbedding(vector: [1, 0, 0], modelVersion: "1.0")

        let distance = embedding1.distance(to: embedding2)

        XCTAssertEqual(distance, 1.0)
    }

    func testEmbeddingEquatable() {
        let embedding1 = SpeakerEmbedding(vector: [1, 2, 3], modelVersion: "1.0")
        let embedding2 = SpeakerEmbedding(vector: [1, 2, 3], modelVersion: "1.0")
        let embedding3 = SpeakerEmbedding(vector: [1, 2, 4], modelVersion: "1.0")

        XCTAssertEqual(embedding1, embedding2)
        XCTAssertNotEqual(embedding1, embedding3)
    }

    func testEmbeddingCodable() throws {
        let original = SpeakerEmbedding(vector: [1.5, 2.5, 3.5], modelVersion: "test-v1")

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(SpeakerEmbedding.self, from: data)

        XCTAssertEqual(original, decoded)
    }

    func testAverageEmbeddingsEmpty() {
        let result = SpeakerEmbedding.average([], modelVersion: "1.0")
        XCTAssertNil(result)
    }

    func testAverageEmbeddingsSingle() {
        let embedding = SpeakerEmbedding(vector: [1, 2, 3], modelVersion: "1.0")
        let result = SpeakerEmbedding.average([embedding], modelVersion: "1.0")

        XCTAssertEqual(result?.vector, [1, 2, 3])
    }

    func testAverageEmbeddingsMultiple() {
        let e1 = SpeakerEmbedding(vector: [2, 4, 6], modelVersion: "1.0")
        let e2 = SpeakerEmbedding(vector: [4, 6, 8], modelVersion: "1.0")
        let result = SpeakerEmbedding.average([e1, e2], modelVersion: "1.0")

        XCTAssertEqual(result?.vector, [3, 5, 7])
    }

    func testAverageEmbeddingsMismatchedLengths() {
        let e1 = SpeakerEmbedding(vector: [1, 2, 3], modelVersion: "1.0")
        let e2 = SpeakerEmbedding(vector: [1, 2], modelVersion: "1.0")
        let result = SpeakerEmbedding.average([e1, e2], modelVersion: "1.0")

        XCTAssertNil(result)
    }
}
