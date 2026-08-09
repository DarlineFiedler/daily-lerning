import AudioToolbox

/// Kurze Effekt-Sounds für besondere Lern-Momente (Kombo-Meilensteine, Issue #90).
/// Bewusst über die System-Sound-API (`AudioServicesPlaySystemSound`) statt eigener
/// Audio-Assets: keine gebündelten Dateien, kein `AVAudioPlayer`-Lebenszyklus – die
/// Meilenstein-Erkennung selbst liegt (testbar) in `PracticeSession.isComboMilestone`.
@MainActor
enum SoundService {
    /// Ein knappes, positives System-Signal beim Erreichen einer Kombo-Schwelle.
    static func playComboMilestone() {
        // 1057 = „Tink" – kurz und unaufdringlich, passend zum flüchtigen Kombo-Feedback.
        AudioServicesPlaySystemSound(1057)
    }
}
