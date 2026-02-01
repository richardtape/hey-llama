import Foundation

enum EnrollmentPrompts {
    /// The standard enrollment phrases used for voice registration
    static let phrases: [String] = [
        "Hey Llama, what's the weather like today?",
        "The quick brown fox jumps over the lazy dog.",
        "My name is [NAME] and I'm setting up my voice.",
        "Please set a reminder for tomorrow morning at nine.",
        "Hey Llama, tell me something interesting."
    ]

    /// Get a specific phrase, substituting the user's name if needed
    static func getPhrase(at index: Int, forName name: String) -> String {
        let wrappedIndex = index % phrases.count
        let phrase = phrases[wrappedIndex]
        return phrase.replacingOccurrences(of: "[NAME]", with: name)
    }

    /// Total number of enrollment phrases
    static var count: Int {
        phrases.count
    }

    /// Instructions shown to user before recording
    static let instructions = """
        Please speak each phrase clearly and naturally.
        Try to maintain a consistent volume and speak
        at your normal pace.
        """

    /// Tips for better enrollment
    static let tips = [
        "Speak in a quiet environment",
        "Hold your device at a comfortable distance",
        "Speak naturally, as you would in conversation",
        "If you make a mistake, you can re-record"
    ]
}
