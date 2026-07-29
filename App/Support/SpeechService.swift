import AVFoundation
import UIKit

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

    /// Cache der Stimmen-Verfügbarkeit je Sprachcode. `AVSpeechSynthesisVoice(language:)`
    /// enumeriert jedes Mal alle Stimmen. Ohne Cache lief das u.a. beim Session-Aufbau und
    /// – teurer – in jedem Render von `SpeakButton`. `NSLock`, weil `isAvailable`
    /// `nonisolated` ist. Der Cache wird beim Aktivwerden der App geleert (siehe
    /// `cacheInvalidation`), damit eine in den System-Einstellungen nachinstallierte
    /// Stimme ohne Neustart erkannt wird.
    nonisolated(unsafe) private static var availabilityCache: [String: Bool] = [:]
    nonisolated private static let availabilityLock = NSLock()

    /// Registriert einmalig einen Beobachter, der den Cache beim Aktivwerden der App leert.
    /// `static let` ⇒ genau einmal ausgewertet und thread-safe; die Referenz in
    /// `isAvailable` löst diese Auswertung beim ersten Aufruf aus.
    nonisolated private static let cacheInvalidation: Void = {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification, object: nil, queue: nil
        ) { _ in
            availabilityLock.lock()
            availabilityCache.removeAll()
            availabilityLock.unlock()
        }
    }()

    /// Ist für die Sprache eine Stimme installiert? Wenn nein, sollte der Speaker-Button
    /// ausgeblendet/deaktiviert werden. Ergebnis wird je Sprachcode zwischengespeichert.
    nonisolated static func isAvailable(language: String = "ko-KR") -> Bool {
        _ = cacheInvalidation // einmalige Registrierung des Invalidierungs-Beobachters
        availabilityLock.lock()
        defer { availabilityLock.unlock() }
        if let cached = availabilityCache[language] { return cached }
        let available = AVSpeechSynthesisVoice(language: language) != nil
        availabilityCache[language] = available
        return available
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
