import Foundation
import FluidAudio

/// SpeakerService implementation for speaker identification and enrollment
/// Uses FluidAudio's DiarizerManager and SpeakerManager for 256-d speaker embeddings
actor SpeakerService: SpeakerServiceProtocol {
    private var diarizer: DiarizerManager?
    private let store: SpeakerStore
    private var speakers: [Speaker] = []
    private let identificationThreshold: Float

    private let modelVersion = "wespeaker-v2"
    private let requiredSamples = 8
    private let minAdaptiveThreshold: Float = 0.50
    private let maxAdaptiveThreshold: Float = 0.80

    var isModelLoaded: Bool {
        diarizer != nil
    }

    var enrolledSpeakers: [Speaker] {
        speakers
    }

    init(
        store: SpeakerStore = SpeakerStore(),
        identificationThreshold: Float = 0.40  // ~2x typical intra-speaker distance
    ) {
        self.store = store
        self.identificationThreshold = identificationThreshold
    }

    func loadModel() async throws {
        let startTime = Date()

        // Download models (one-time setup)
        let models = try await DiarizerModels.downloadIfNeeded()

        // Initialize DiarizerManager
        let diarizerInstance = DiarizerManager()
        diarizerInstance.initialize(models: models)
        diarizer = diarizerInstance

        // Load persisted speakers
        speakers = store.loadSpeakers()
        print("[SpeakerService] Loaded \(speakers.count) speaker(s) from storage")

        // Register known speakers in SpeakerManager using upsertSpeaker
        for speaker in speakers {
            print("[SpeakerService] Registering speaker: \(speaker.name) (ID: \(speaker.id.uuidString))")
            print("[SpeakerService]   Embedding: \(speaker.embedding.vector.count) dims, first 5: \(speaker.embedding.vector.prefix(5).map { String(format: "%.4f", $0) }.joined(separator: ", "))")
            diarizer?.speakerManager.upsertSpeaker(
                id: speaker.id.uuidString,
                currentEmbedding: speaker.embedding.vector,
                duration: 0,
                isPermanent: true
            )
        }

        let loadTime = Date().timeIntervalSince(startTime)
        print("[SpeakerService] Model loaded in \(String(format: "%.2f", loadTime))s with \(speakers.count) enrolled speaker(s)")
    }

    func identify(_ audio: AudioChunk, thresholdOverride: Float? = nil) async -> Speaker? {
        guard let diarizer = diarizer else {
            print("[Identify] ERROR: model not loaded, skipping identification")
            return nil
        }

        guard !speakers.isEmpty else {
            print("[Identify] ERROR: no enrolled speakers to match against")
            return nil
        }

        print("[Identify] Processing audio: \(audio.samples.count) samples (\(String(format: "%.2f", audio.duration))s)")

        do {
            // Process audio through diarizer to get speaker segments
            let result = try diarizer.performCompleteDiarization(audio.samples)
            print("[Identify] Diarization found \(result.segments.count) segment(s)")

            guard !result.segments.isEmpty else {
                print("[Identify] No speech detected in audio")
                return nil
            }
            print("[Identify] First segment speaker ID: \(result.segments.first?.speakerId ?? "unknown")")

            // Build an averaged embedding across all detected segments
            var segmentEmbeddings: [SpeakerEmbedding] = []
            for segment in result.segments {
                guard let fluidSpeaker = diarizer.speakerManager.getSpeaker(for: segment.speakerId) else {
                    print("[Identify] WARNING: Could not retrieve speaker embedding for ID: \(segment.speakerId)")
                    continue
                }
                let embedding = SpeakerEmbedding(
                    vector: fluidSpeaker.currentEmbedding,
                    modelVersion: modelVersion
                )
                segmentEmbeddings.append(embedding)
            }

            guard let inputEmbedding = SpeakerEmbedding.average(segmentEmbeddings, modelVersion: modelVersion) else {
                print("[Identify] ERROR: Failed to average embeddings across segments")
                return nil
            }
            print("[Identify] Input embedding (avg of \(segmentEmbeddings.count) segment(s)): \(inputEmbedding.vector.count) dims, first 5: \(inputEmbedding.vector.prefix(5).map { String(format: "%.4f", $0) }.joined(separator: ", "))")

            // Find the best matching enrolled speaker by embedding distance
            var bestMatch: Speaker?
            var bestDistance: Float = Float.greatestFiniteMagnitude

            print("[Identify] Comparing against \(speakers.count) enrolled speaker(s):")
            for speaker in speakers {
                let distance = inputEmbedding.distance(to: speaker.embedding)
                let baseThreshold = speaker.metadata.identificationThreshold ?? identificationThreshold
                let speakerThreshold = max(baseThreshold, thresholdOverride ?? baseThreshold)
                let status = distance < speakerThreshold ? "MATCH" : "no match"
                print("[Identify]   \(speaker.name): distance = \(String(format: "%.4f", distance)) (\(status), threshold: \(String(format: "%.4f", speakerThreshold)))")

                if distance < bestDistance {
                    bestDistance = distance
                    bestMatch = speaker
                }
            }

            // Check if the best match is within threshold
            if let matchedSpeaker = bestMatch {
                let matchedBaseThreshold = matchedSpeaker.metadata.identificationThreshold ?? identificationThreshold
                let matchedThreshold = max(matchedBaseThreshold, thresholdOverride ?? matchedBaseThreshold)
                if bestDistance < matchedThreshold {
                    print("[Identify] SUCCESS: Identified as \(matchedSpeaker.name) (distance: \(String(format: "%.4f", bestDistance)))")

                    // Update metadata
                    var updatedSpeaker = matchedSpeaker
                    updatedSpeaker.metadata.lastSeenAt = Date()
                    updatedSpeaker.metadata.commandCount += 1
                    try? await updateSpeaker(updatedSpeaker)

                    return matchedSpeaker
                }
            }

            let matchName = bestMatch?.name ?? "none"
            let matchThreshold = bestMatch?.metadata.identificationThreshold ?? identificationThreshold
            print("[Identify] FAILED: Best match was \(matchName) at distance \(String(format: "%.4f", bestDistance)), but threshold is \(String(format: "%.4f", matchThreshold))")
            return nil
        } catch {
            print("Speaker identification failed: \(error)")
            return nil
        }
    }

    func enroll(name: String, samples: [AudioChunk]) async throws -> Speaker {
        guard let diarizer = diarizer else {
            throw SpeakerServiceError.modelNotLoaded
        }

        guard samples.count >= requiredSamples else {
            throw SpeakerServiceError.insufficientSamples(required: requiredSamples, provided: samples.count)
        }

        // Extract embedding from each sample separately, then average
        var embeddings: [SpeakerEmbedding] = []

        for (index, sample) in samples.enumerated() {
            print("[Enrollment] Processing sample \(index + 1): \(sample.samples.count) samples (\(String(format: "%.2f", sample.duration))s)")

            // Process each sample individually
            let result = try diarizer.performCompleteDiarization(sample.samples)

            guard let firstSegment = result.segments.first else {
                print("[Enrollment] WARNING: No speech detected in sample \(index + 1), skipping")
                continue
            }

            guard let fluidSpeaker = diarizer.speakerManager.getSpeaker(for: firstSegment.speakerId) else {
                print("[Enrollment] WARNING: Could not get embedding for sample \(index + 1), skipping")
                continue
            }

            let sampleEmbedding = SpeakerEmbedding(
                vector: fluidSpeaker.currentEmbedding,
                modelVersion: modelVersion
            )
            embeddings.append(sampleEmbedding)
            print("[Enrollment] Sample \(index + 1) embedding first 5: \(sampleEmbedding.vector.prefix(5).map { String(format: "%.4f", $0) }.joined(separator: ", "))")

            // Clean up the auto-generated speaker to avoid polluting the manager
            diarizer.speakerManager.removeSpeaker(firstSegment.speakerId)
        }

        guard !embeddings.isEmpty else {
            throw SpeakerServiceError.embeddingExtractionFailed("No valid embeddings extracted from samples")
        }

        print("[Enrollment] Extracted \(embeddings.count) embeddings")

        // Show how consistent the embeddings are with each other
        if embeddings.count >= 2 {
            print("[Enrollment] Intra-speaker distances (how similar your own samples are):")
            for i in 0..<embeddings.count {
                for j in (i+1)..<embeddings.count {
                    let dist = embeddings[i].distance(to: embeddings[j])
                    print("[Enrollment]   Sample \(i+1) vs Sample \(j+1): \(String(format: "%.4f", dist))")
                }
            }
        }

        // Average the embeddings
        guard let averagedEmbedding = SpeakerEmbedding.average(embeddings, modelVersion: modelVersion) else {
            throw SpeakerServiceError.embeddingExtractionFailed("Failed to average embeddings")
        }

        print("[Enrollment] Averaged embedding first 5 values: \(averagedEmbedding.vector.prefix(5).map { String(format: "%.4f", $0) }.joined(separator: ", "))")

        // Show distance from each sample to the average
        print("[Enrollment] Distance from each sample to averaged embedding:")
        let distancesToAverage = embeddings.map { $0.distance(to: averagedEmbedding) }
        for (i, dist) in distancesToAverage.enumerated() {
            print("[Enrollment]   Sample \(i+1): \(String(format: "%.4f", dist))")
        }

        let adaptiveThreshold = computeAdaptiveThreshold(from: distancesToAverage)
        print("[Enrollment] Adaptive threshold: \(String(format: "%.4f", adaptiveThreshold))")

        let speaker = Speaker(
            name: name,
            embedding: averagedEmbedding,
            metadata: SpeakerMetadata(identificationThreshold: adaptiveThreshold)
        )
        print("[Enrollment] Created speaker: \(speaker.name) with ID: \(speaker.id)")

        // Register in SpeakerManager with our UUID for future lookups
        diarizer.speakerManager.upsertSpeaker(
            id: speaker.id.uuidString,
            currentEmbedding: averagedEmbedding.vector,
            duration: 0,
            isPermanent: true
        )

        // Add to our list and persist
        speakers.append(speaker)
        try store.saveSpeakers(speakers)

        print("[Enrollment] SUCCESS - Enrolled speaker: \(name)")
        print("[Enrollment] Total enrolled speakers: \(speakers.count)")
        print("[Enrollment] Saved to: \(store.speakersFileURL.path)")
        return speaker
    }

    private func computeAdaptiveThreshold(from distances: [Float]) -> Float {
        guard !distances.isEmpty else {
            return identificationThreshold
        }

        let mean = distances.reduce(0, +) / Float(distances.count)
        let variance = distances.reduce(0) { partial, value in
            let diff = value - mean
            return partial + diff * diff
        } / Float(distances.count)
        let stdDev = sqrt(variance)
        let rawThreshold = mean + (2 * stdDev)

        let clamped = max(minAdaptiveThreshold, min(maxAdaptiveThreshold, rawThreshold))
        return clamped.isFinite ? clamped : identificationThreshold
    }

    func remove(_ speaker: Speaker) async throws {
        guard let index = speakers.firstIndex(where: { $0.id == speaker.id }) else {
            throw SpeakerServiceError.speakerNotFound
        }

        // Remove from FluidAudio SpeakerManager
        diarizer?.speakerManager.removeSpeaker(speaker.id.uuidString)

        // Remove from our list and persist
        speakers.remove(at: index)
        try store.saveSpeakers(speakers)

        print("Removed speaker: \(speaker.name)")
    }

    func updateSpeaker(_ speaker: Speaker) async throws {
        guard let index = speakers.firstIndex(where: { $0.id == speaker.id }) else {
            throw SpeakerServiceError.speakerNotFound
        }

        speakers[index] = speaker
        try store.saveSpeakers(speakers)

        // Update in FluidAudio SpeakerManager using parameter-based method
        diarizer?.speakerManager.upsertSpeaker(
            id: speaker.id.uuidString,
            currentEmbedding: speaker.embedding.vector,
            duration: 0,
            isPermanent: true
        )
    }
}
