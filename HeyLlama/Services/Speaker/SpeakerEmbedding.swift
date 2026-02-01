import Foundation

/// Speaker voice embedding vector for identification
/// Marked nonisolated to allow use from any actor context
nonisolated struct SpeakerEmbedding: Codable, Equatable, Sendable {
    let vector: [Float]
    let modelVersion: String

    nonisolated init(vector: [Float], modelVersion: String) {
        self.vector = vector
        self.modelVersion = modelVersion
    }

    /// Calculate cosine distance to another embedding (0 = identical, 1 = orthogonal/different)
    nonisolated func distance(to other: SpeakerEmbedding) -> Float {
        guard vector.count == other.vector.count, !vector.isEmpty else {
            return 1.0 // Max distance for incompatible embeddings
        }

        var dotProduct: Float = 0
        var normA: Float = 0
        var normB: Float = 0

        for i in 0..<vector.count {
            dotProduct += vector[i] * other.vector[i]
            normA += vector[i] * vector[i]
            normB += other.vector[i] * other.vector[i]
        }

        // Handle zero vectors
        guard normA > 0 && normB > 0 else {
            return 1.0
        }

        let similarity = dotProduct / (sqrt(normA) * sqrt(normB))
        // Clamp similarity to [-1, 1] to handle floating point errors
        let clampedSimilarity = max(-1, min(1, similarity))
        return 1 - clampedSimilarity
    }

    /// Calculate average embedding from multiple samples
    nonisolated static func average(_ embeddings: [SpeakerEmbedding], modelVersion: String) -> SpeakerEmbedding? {
        guard !embeddings.isEmpty else { return nil }
        guard let firstLength = embeddings.first?.vector.count else { return nil }

        // Verify all embeddings have same length
        guard embeddings.allSatisfy({ $0.vector.count == firstLength }) else {
            return nil
        }

        var averaged = [Float](repeating: 0, count: firstLength)

        for embedding in embeddings {
            for i in 0..<firstLength {
                averaged[i] += embedding.vector[i]
            }
        }

        let count = Float(embeddings.count)
        for i in 0..<firstLength {
            averaged[i] /= count
        }

        return SpeakerEmbedding(vector: averaged, modelVersion: modelVersion)
    }
}
