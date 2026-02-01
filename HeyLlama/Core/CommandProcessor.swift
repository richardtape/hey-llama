import Foundation

final class CommandProcessor {
    private let wakePhrases: [String]

    /// Initialize with a primary wake phrase and optional alternatives
    /// Default includes common transcription variants of "hey llama"
    init(wakePhrase: String = "hey llama", alternatives: [String]? = nil) {
        let primary = wakePhrase.lowercased()
        let alts = alternatives ?? Self.defaultAlternatives(for: primary)
        self.wakePhrases = [primary] + alts.map { $0.lowercased() }
    }

    /// Common transcription variants for known wake phrases
    private static func defaultAlternatives(for phrase: String) -> [String] {
        switch phrase {
        case "hey llama":
            return ["hey lama", "hey llamma", "hey lamma"]
        default:
            return []
        }
    }

    /// Check if text contains any wake phrase variant
    func containsWakeWord(in text: String) -> Bool {
        let lowercased = text.lowercased()
        return wakePhrases.contains { lowercased.contains($0) }
    }

    /// Extract command text after wake phrase, or nil if not found/empty
    func extractCommand(from text: String) -> String? {
        let lowercased = text.lowercased()

        // Find the first matching wake phrase
        var matchRange: Range<String.Index>?
        for phrase in wakePhrases {
            if let range = lowercased.range(of: phrase) {
                matchRange = range
                break
            }
        }

        guard let range = matchRange else {
            return nil
        }

        // Get everything after the wake phrase
        let afterWakePhrase = text[range.upperBound...]

        // Trim whitespace and leading punctuation (comma, colon)
        var command = String(afterWakePhrase)
            .trimmingCharacters(in: .whitespaces)

        // Remove leading comma or colon if present
        if command.hasPrefix(",") || command.hasPrefix(":") {
            command = String(command.dropFirst())
                .trimmingCharacters(in: .whitespaces)
        }

        // Return nil if empty after trimming
        guard !command.isEmpty else {
            return nil
        }

        return command
    }
}
