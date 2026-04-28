import AVFoundation

/// Thin wrapper around AVSpeechSynthesizer for gesture announcements.
@MainActor
final class SpeechManager {
    static let shared = SpeechManager()
    private let synthesizer = AVSpeechSynthesizer()

    private init() {}

    func announce(_ text: String) {
        guard !text.isEmpty else { return }
        // If something is already mid-utterance, drop new ones to avoid spam.
        if synthesizer.isSpeaking { return }
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = 0.55
        utterance.volume = 0.7
        synthesizer.speak(utterance)
    }
}
