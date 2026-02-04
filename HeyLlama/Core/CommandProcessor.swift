import Foundation

final class CommandProcessor {
    private let wakeNameVariants: [[String]]
    private let closingPhrases: Set<String>
    private let requireHeyPrefix: Bool

    /// Initialize with a primary wake phrase and optional alternatives
    /// Default includes common transcription variants of "hey llama"
    init(
        wakePhrase: String = "hey llama",
        alternatives: [String]? = nil,
        closingPhrases: [String]? = nil,
        requireHeyPrefix: Bool = false
    ) {
        let primaryTokens = Self.normalizeNameTokens(from: wakePhrase)
        let alternativeTokens = (alternatives ?? Self.defaultAlternatives(for: wakePhrase))
            .map { Self.normalizeNameTokens(from: $0) }
            .filter { !$0.isEmpty }
        self.wakeNameVariants = ([primaryTokens] + alternativeTokens)
            .filter { !$0.isEmpty }

        let defaults = closingPhrases ?? Self.defaultClosingPhrases(for: wakePhrase.lowercased())
        self.closingPhrases = Set(defaults.map { $0.lowercased() })
        self.requireHeyPrefix = requireHeyPrefix
    }

    /// Common transcription variants for known wake names.
    private static func defaultAlternatives(for phrase: String) -> [String] {
        let normalized = normalizeNameTokens(from: phrase)
        guard normalized.count == 1, let token = normalized.first else {
            return []
        }

        switch token {
        case "llama":
            return ["lama", "llamma", "lamma"]
        default:
            return []
        }
    }

    private static func defaultClosingPhrases(for wakePhrase: String) -> [String] {
        let assistantName = wakePhrase
            .split(separator: " ")
            .last
            .map { String($0) } ?? "llama"
        return [
            "thanks",
            "thank you",
            "thanks \(assistantName)",
            "thank you \(assistantName)",
            "that's all",
            "that is all",
            "that's it",
            "that is it",
            "goodbye",
            "bye",
            "stop",
            "stop listening",
            "cancel"
        ]
    }

    /// Check if text contains any wake phrase variant
    func containsWakeWord(in text: String) -> Bool {
        return findWakeMatch(in: text) != nil
    }

    /// Check if text is a closing phrase (normalized)
    func isClosingPhrase(_ text: String) -> Bool {
        let normalized = normalizeText(text)
        guard !normalized.isEmpty else {
            return false
        }

        for phrase in closingPhrases {
            let normalizedPhrase = normalizeText(phrase)
            if normalized == normalizedPhrase {
                return true
            }
            if normalized.hasSuffix(" \(normalizedPhrase)") {
                return true
            }
        }

        return false
    }

    /// Extract command text after wake phrase, or nil if not found/empty
    func extractCommand(from text: String) -> String? {
        guard let match = findWakeMatch(in: text) else {
            return nil
        }

        let command: String
        switch match.position {
        case .start:
            let afterWakePhrase = text[match.lastTokenRange.upperBound...]
            command = trimCommandLeading(String(afterWakePhrase))
        case .end:
            let beforeWakePhrase = text[..<match.firstTokenRange.lowerBound]
            command = trimCommandTrailing(String(beforeWakePhrase))
        }

        guard !command.isEmpty else {
            return nil
        }

        return command
    }

    private func normalizeText(_ text: String) -> String {
        let lowered = text.lowercased()
        let replaced = lowered.replacingOccurrences(of: "[^a-z0-9\\s]", with: " ", options: .regularExpression)
        let collapsed = replaced.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return collapsed.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Wake Word Matching

    private enum WakeMatchPosition {
        case start
        case end
    }

    private struct WakeMatch {
        let firstTokenRange: Range<String.Index>
        let lastTokenRange: Range<String.Index>
        let position: WakeMatchPosition
    }

    private struct TokenRange {
        let token: String
        let range: Range<String.Index>
    }

    private func findWakeMatch(in text: String) -> WakeMatch? {
        let tokens = tokenize(text)
        guard !tokens.isEmpty else {
            return nil
        }

        let tokenStrings = tokens.map { $0.token }
        let sequences = buildWakeTokenSequences()
        guard !sequences.isEmpty else {
            return nil
        }

        // Prefer start-position matches.
        if let match = findStartWakeMatch(tokens: tokens, tokenStrings: tokenStrings, sequences: sequences) {
            return match
        }

        // Otherwise, allow end-position matches.
        return findEndWakeMatch(tokens: tokens, tokenStrings: tokenStrings, sequences: sequences)
    }

    private func buildWakeTokenSequences() -> [[String]] {
        var sequences: [[String]] = []

        for tokens in wakeNameVariants {
            guard !tokens.isEmpty else { continue }
            sequences.append(tokens)
            sequences.append(["hey"] + tokens)
        }

        if requireHeyPrefix {
            sequences = sequences.filter { $0.first == "hey" }
        }

        let unique = Array(Set(sequences.map { $0.joined(separator: " ") }))
            .map { $0.split(separator: " ").map(String.init) }
        return unique.sorted { $0.count > $1.count }
    }

    private func findStartWakeMatch(
        tokens: [TokenRange],
        tokenStrings: [String],
        sequences: [[String]]
    ) -> WakeMatch? {
        for sequence in sequences {
            let length = sequence.count
            guard length <= tokenStrings.count else { continue }

            for i in 0...(tokenStrings.count - length) {
                guard tokenStrings[i..<i + length].elementsEqual(sequence) else {
                    continue
                }
                if tokensBeforeArePolite(tokenStrings, endIndex: i) {
                    let firstRange = tokens[i].range
                    let lastRange = tokens[i + length - 1].range
                    return WakeMatch(
                        firstTokenRange: firstRange,
                        lastTokenRange: lastRange,
                        position: .start
                    )
                }
            }
        }
        return nil
    }

    private func findEndWakeMatch(
        tokens: [TokenRange],
        tokenStrings: [String],
        sequences: [[String]]
    ) -> WakeMatch? {
        var bestMatch: WakeMatch?
        var bestIndex = -1

        for sequence in sequences {
            let length = sequence.count
            guard length <= tokenStrings.count else { continue }

            for i in 0...(tokenStrings.count - length) {
                guard tokenStrings[i..<i + length].elementsEqual(sequence) else {
                    continue
                }
                let endIndex = i + length
                if tokensAfterArePolite(tokenStrings, startIndex: endIndex) {
                    if i >= bestIndex {
                        bestIndex = i
                        let firstRange = tokens[i].range
                        let lastRange = tokens[i + length - 1].range
                        bestMatch = WakeMatch(
                            firstTokenRange: firstRange,
                            lastTokenRange: lastRange,
                            position: .end
                        )
                    }
                }
            }
        }

        return bestMatch
    }

    private func tokensBeforeArePolite(_ tokens: [String], endIndex: Int) -> Bool {
        guard endIndex > 0 else {
            return true
        }
        let polite = politeTokens()
        return tokens[0..<endIndex].allSatisfy { polite.contains($0) }
    }

    private func tokensAfterArePolite(_ tokens: [String], startIndex: Int) -> Bool {
        guard startIndex < tokens.count else {
            return true
        }
        let polite = politeTokens()
        return tokens[startIndex..<tokens.count].allSatisfy { polite.contains($0) }
    }

    private func politeTokens() -> Set<String> {
        [
            "please",
            "pls",
            "kindly",
            "hey",
            "thanks",
            "thank",
            "you"
        ]
    }

    private func tokenize(_ text: String) -> [TokenRange] {
        var tokens: [TokenRange] = []
        var tokenStart: String.Index?

        for index in text.indices {
            let scalar = text.unicodeScalars[index]
            if CharacterSet.alphanumerics.contains(scalar) {
                if tokenStart == nil {
                    tokenStart = index
                }
            } else if let start = tokenStart {
                let range = start..<index
                let token = String(text[range]).lowercased()
                tokens.append(TokenRange(token: token, range: range))
                tokenStart = nil
            }
        }

        if let start = tokenStart {
            let range = start..<text.endIndex
            let token = String(text[range]).lowercased()
            tokens.append(TokenRange(token: token, range: range))
        }

        return tokens
    }

    private static func normalizeNameTokens(from phrase: String) -> [String] {
        let tokens = tokenizeStatic(phrase)
        guard !tokens.isEmpty else {
            return []
        }
        if tokens.first == "hey" {
            let trimmed = Array(tokens.dropFirst())
            return trimmed.isEmpty ? tokens : trimmed
        }
        return tokens
    }

    private func normalizeNameTokens(from phrase: String) -> [String] {
        Self.normalizeNameTokens(from: phrase)
    }

    private static func tokenizeStatic(_ text: String) -> [String] {
        var tokens: [String] = []
        var tokenStart: String.Index?

        for index in text.indices {
            let scalar = text.unicodeScalars[index]
            if CharacterSet.alphanumerics.contains(scalar) {
                if tokenStart == nil {
                    tokenStart = index
                }
            } else if let start = tokenStart {
                let range = start..<index
                let token = String(text[range]).lowercased()
                tokens.append(token)
                tokenStart = nil
            }
        }

        if let start = tokenStart {
            let range = start..<text.endIndex
            let token = String(text[range]).lowercased()
            tokens.append(token)
        }

        return tokens
    }

    private func trimCommandLeading(_ text: String) -> String {
        var command = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if command.hasPrefix(",") || command.hasPrefix(":") {
            command = String(command.dropFirst())
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return command
    }

    private func trimCommandTrailing(_ text: String) -> String {
        var command = text.trimmingCharacters(in: .whitespacesAndNewlines)
        while command.hasSuffix(",") || command.hasSuffix(":") {
            command = String(command.dropLast())
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return command
    }
}
