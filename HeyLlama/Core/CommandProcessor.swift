import Foundation

final class CommandProcessor {
    private let wakePhrase: String
    private let wakePhraseLength: Int

    init(wakePhrase: String = "hey llama") {
        self.wakePhrase = wakePhrase.lowercased()
        self.wakePhraseLength = wakePhrase.count
    }

    /// Check if text contains the wake word
    func containsWakeWord(in text: String) -> Bool {
        text.lowercased().contains(wakePhrase)
    }

    /// Extract command text after wake phrase, or nil if not found/empty
    func extractCommand(from text: String) -> String? {
        let lowercased = text.lowercased()

        guard let range = lowercased.range(of: wakePhrase) else {
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
