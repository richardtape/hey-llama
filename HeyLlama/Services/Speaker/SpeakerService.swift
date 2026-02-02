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
    private let requiredSamples = 5

    var isModelLoaded: Bool {
        diarizer != nil
    }

    var enrolledSpeakers: [Speaker] {
        speakers
    }

    init(
        store: SpeakerStore = SpeakerStore(),
        identificationThreshold: Float = 0.5
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

        // Register known speakers in SpeakerManager using upsertSpeaker
        for speaker in speakers {
            diarizer?.speakerManager.upsertSpeaker(
                id: speaker.id.uuidString,
                currentEmbedding: speaker.embedding.vector,
                duration: 0,
                isPermanent: true
            )
        }

        let loadTime = Date().timeIntervalSince(startTime)
        print("Speaker embedding model loaded in \(String(format: "%.2f", loadTime))s")
        print("Loaded \(speakers.count) enrolled speaker(s)")
    }

    func identify(_ audio: AudioChunk) async -> Speaker? {
        guard let diarizer = diarizer else {
            print("Speaker service: model not loaded, skipping identification")
            return nil
        }

        guard !speakers.isEmpty else {
            return nil
        }

        do {
            // Process audio through diarizer to get speaker segments
            let result = try diarizer.performCompleteDiarization(audio.samples)

            // Get the first/primary speaker from the result
            guard let firstSegment = result.segments.first else {
                print("No speech detected in audio")
                return nil
            }

            // Find matching speaker from our enrolled speakers
            let speakerId = firstSegment.speakerId

            // Look up in our stored speakers by matching the FluidAudio speaker ID
            if let matchedSpeaker = speakers.first(where: { $0.id.uuidString == speakerId }) {
                print("Speaker identified: \(matchedSpeaker.name)")

                // Update metadata
                var updatedSpeaker = matchedSpeaker
                updatedSpeaker.metadata.lastSeenAt = Date()
                updatedSpeaker.metadata.commandCount += 1
                try? await updateSpeaker(updatedSpeaker)

                return matchedSpeaker
            } else {
                // Speaker not in our enrolled list - might be a new unknown speaker
                print("No enrolled speaker match for ID: \(speakerId)")
                return nil
            }
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

        // Combine all audio samples for enrollment
        var allSamples: [Float] = []
        for sample in samples {
            allSamples.append(contentsOf: sample.samples)
        }

        // Process combined audio to extract speaker embedding
        let result = try diarizer.performCompleteDiarization(allSamples)

        guard let firstSegment = result.segments.first else {
            throw SpeakerServiceError.embeddingExtractionFailed("No speech detected in enrollment audio")
        }

        // Get the speaker from SpeakerManager to access the embedding
        guard let fluidSpeaker = diarizer.speakerManager.getSpeaker(for: firstSegment.speakerId) else {
            throw SpeakerServiceError.embeddingExtractionFailed("Could not retrieve speaker embedding")
        }

        // Create our Speaker model with the extracted embedding
        let embedding = SpeakerEmbedding(
            vector: fluidSpeaker.currentEmbedding,
            modelVersion: modelVersion
        )

        let speaker = Speaker(
            name: name,
            embedding: embedding
        )

        // Register in SpeakerManager with our UUID for future lookups
        // Use upsertSpeaker with parameters to avoid type conflict
        diarizer.speakerManager.upsertSpeaker(
            id: speaker.id.uuidString,
            currentEmbedding: embedding.vector,
            duration: fluidSpeaker.duration,
            isPermanent: true
        )

        // Remove the auto-generated speaker ID from diarization
        if firstSegment.speakerId != speaker.id.uuidString {
            diarizer.speakerManager.removeSpeaker(firstSegment.speakerId)
        }

        // Add to our list and persist
        speakers.append(speaker)
        try store.saveSpeakers(speakers)

        print("Enrolled speaker: \(name)")
        return speaker
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
