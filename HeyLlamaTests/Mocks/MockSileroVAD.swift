import Foundation
@testable import HeyLlama

/// Mock VAD for testing - returns configurable probabilities synchronously
final class MockVADProcessor: VADProcessorProtocol {
    var probabilitiesToReturn: [Float] = []
    private var callIndex = 0

    func process(_ samples: [Float]) async -> Float {
        guard callIndex < probabilitiesToReturn.count else {
            return 0.0
        }
        let probability = probabilitiesToReturn[callIndex]
        callIndex += 1
        return probability
    }

    func reset() {
        callIndex = 0
    }
}

/// Synchronous mock for simpler test cases
final class SyncMockVADProcessor: VADProcessorProtocol {
    var probabilityToReturn: Float = 0.0

    func process(_ samples: [Float]) async -> Float {
        return probabilityToReturn
    }
}
