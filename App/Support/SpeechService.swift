import AVFoundation

/// Sprachausgabe (Text-to-Speech) für Vokabeln – komplett offline via
/// `AVSpeechSynthesizer`, keine externen Abhängigkeiten. Standardsprache Koreanisch.
@MainActor
final class SpeechService: NSObject {
    static let shared = SpeechService()

    private let synthesizer = AVSpeechSynthesizer()

    private override init() {
        super.init()
        synthesizer.delegate = self
    }

    /// Ist für die Sprache eine Stimme installiert? Wenn nein, sollte der Speaker-Button
    /// ausgeblendet/deaktiviert werden.
    nonisolated static func isAvailable(language: String = "ko-KR") -> Bool {
        AVSpeechSynthesisVoice(language: language) != nil
    }

    /// Spricht den Text. Unterbricht eine laufende Ausgabe. Duckt kurz laufende
    /// Fremd-Audio (Musik/Podcast), damit die Aussprache klar hörbar ist.
    func speak(_ text: String, language: String = "ko-KR") {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let voice = AVSpeechSynthesisVoice(language: language) else { return }

        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        activateSession()
        let utterance = AVSpeechUtterance(string: trimmed)
        utterance.voice = voice
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9 // etwas langsamer zum Nachsprechen
        synthesizer.speak(utterance)
    }

    // MARK: - Audio-Session (Ducking)

    private func activateSession() {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? session.setActive(true)
        #endif
    }

    private func deactivateSession() {
        #if os(iOS)
        // Fremd-Audio wieder auf volle Lautstärke bringen.
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        #endif
    }
}

extension SpeechService: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                                       didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in deactivateSession() }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                                       didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in deactivateSession() }
    }
}
