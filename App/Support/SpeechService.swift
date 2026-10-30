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
        registerSessionResetObservers()
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

    /// Ist die Audio-Session aktuell aktiv (Hardware „warm")? Solange `true`, wird nicht
    /// neu aktiviert – das vermeidet den Kaltstart-Glitch bei jedem weiteren Wort.
    private var sessionActive = false

    /// Verzögerte Deaktivierung. Wir deaktivieren die Session nicht sofort nach jedem Wort,
    /// sondern erst, wenn eine Weile nichts mehr gesprochen wurde. So bleibt die Hardware
    /// während einer Lernsitzung warm und Fremd-Audio wird nach dem letzten Wort wieder
    /// freigegeben.
    private var deactivationTask: Task<Void, Never>?

    /// Sekunden, die die Session nach dem letzten Wort noch aktiv bleibt.
    private let sessionKeepAlive: TimeInterval = 3

    /// Spricht den Text. Unterbricht eine laufende Ausgabe. Duckt kurz laufende
    /// Fremd-Audio (Musik/Podcast), damit die Aussprache klar hörbar ist.
    func speak(_ text: String, language: String = "ko-KR") {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let voice = AVSpeechSynthesisVoice(language: language) else { return }

        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        // Nur beim echten Kaltstart aktivieren; eine bereits aktive Session bleibt warm.
        let wasCold = !sessionActive
        activateSession()
        deactivationTask?.cancel() // geplante Deaktivierung abbrechen, wir sprechen gleich

        let utterance = AVSpeechUtterance(string: trimmed)
        utterance.voice = voice
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9 // etwas langsamer zum Nachsprechen
        if wasCold {
            // Beim Kaltstart braucht die Audio-Hardware ~100 ms bis Route-/Duck-Rampup fertig
            // ist. Diese Stille davor verhindert, dass der Wortanfang abgeschnitten wird.
            utterance.preUtteranceDelay = 0.15
        }
        synthesizer.speak(utterance)
    }

    // MARK: - Audio-Session (Ducking)

    private func activateSession() {
        guard !sessionActive else { return }
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try session.setActive(true)
            sessionActive = true // nur bei Erfolg „warm" merken, sonst beim nächsten Wort erneut versuchen
        } catch {
            sessionActive = false
        }
        #else
        sessionActive = true
        #endif
    }

    /// Plant die Deaktivierung nach einer Ruhephase. Jedes neue Wort bricht sie ab und
    /// plant neu. Ein einzelner cancelbarer Task hält das im selben Isolationsmodell wie
    /// die übrigen Session-Hops.
    private func scheduleDeactivation() {
        deactivationTask?.cancel()
        deactivationTask = Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: UInt64(self.sessionKeepAlive * 1_000_000_000))
            guard !Task.isCancelled, !self.synthesizer.isSpeaking else { return }
            self.deactivateSession()
        }
    }

    private func deactivateSession() {
        guard sessionActive else { return }
        sessionActive = false
        #if os(iOS)
        // Fremd-Audio wieder auf volle Lautstärke bringen.
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        #endif
    }

    /// Das System kann die Session unter uns deaktivieren (Anruf/Siri-Interruption oder
    /// App-Hintergrund ohne Audio-Background-Mode). Ohne Reset bliebe `sessionActive`
    /// fälschlich `true`, der nächste `speak()` übersprünge Reaktivierung + Vorlauf-Stille
    /// und das erste Wort käme wieder stumm/abgeschnitten. Wir markieren die Session daher
    /// als kalt (ohne eigenes `setActive(false)`, das System hat sie bereits abgeschaltet).
    private func registerSessionResetObservers() {
        #if os(iOS)
        let center = NotificationCenter.default
        center.addObserver(forName: AVAudioSession.interruptionNotification,
                           object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.invalidateSession() }
        }
        center.addObserver(forName: UIApplication.didEnterBackgroundNotification,
                           object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.invalidateSession() }
        }
        #endif
    }

    private func invalidateSession() {
        deactivationTask?.cancel()
        sessionActive = false
    }
}

extension SpeechService: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                                       didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in scheduleDeactivation() }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                                       didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in scheduleDeactivation() }
    }
}
