import AVFoundation

/// Sprachausgabe (Text-to-Speech) für Vokabeln – komplett offline via
/// `AVSpeechSynthesizer`, keine externen Abhängigkeiten. Standardsprache Koreanisch.
@MainActor
final class SpeechService {
    static let shared = SpeechService()

    private let synthesizer = AVSpeechSynthesizer()

    private init() {}

    /// Ist für die Sprache eine Stimme installiert? Wenn nein, sollte der Speaker-Button
    /// ausgeblendet/deaktiviert werden.
    static func isAvailable(language: String = "ko-KR") -> Bool {
        AVSpeechSynthesisVoice(language: language) != nil
    }

    /// Spricht den Text. Unterbricht eine laufende Ausgabe.
    func speak(_ text: String, language: String = "ko-KR") {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let voice = AVSpeechSynthesisVoice(language: language) else { return }

        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        let utterance = AVSpeechUtterance(string: trimmed)
        utterance.voice = voice
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9   // etwas langsamer zum Nachsprechen
        synthesizer.speak(utterance)
    }
}
