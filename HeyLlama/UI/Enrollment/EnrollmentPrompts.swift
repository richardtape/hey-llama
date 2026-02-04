import Foundation

enum EnrollmentPrompts {
    static let minimumRequiredCount = 8
    static let optionalExtraCount = 4

    /// The standard enrollment phrases used for voice registration
    static let phrases: [String] = [
        "Hey Llama, what's the weather like today?",
        "The quick brown fox jumps over the lazy dog.",
        "My name is [NAME] and I'm setting up my voice.",
        "Please set a reminder for tomorrow morning at nine.",
        "Hey Llama, tell me something interesting.",
        "I like to plan my day with lists and reminders.",
        "Here is a longer sample to help with voice matching accuracy.",
        "Hey Llama, add milk and eggs to my grocery list.",
        "When I travel, I always pack a scarf and a jacket.",
        "Hey Llama, what's on my calendar tomorrow morning?",
        "Please turn on the living room lights.",
        "Hey Llama, set a timer for ten minutes."
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

    /// Minimum number of phrases required to complete enrollment
    static var minimumRequiredPhrases: Int {
        min(minimumRequiredCount, phrases.count)
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
