import Foundation

/// Reine, testbare Regeln für die TOPIK-Prüfungssimulation (Issue #94). Kein eigener
/// Zustand: alles leitet sich aus den Runden-Zählern (`total`, `correct`) und dem
/// gewählten `TopikLevel` ab. Die Prüfung selbst läuft über eine normale
/// `PracticeSession` (zählt regulär in SRS/XP/Streak); dieses Struct kapselt nur das
/// Zeitbudget, den Prozent-Score und die Bestehensgrenze – analog zu [[BossBattle]].
enum ExamRules {
    /// Zeitbudget je Wort (bewusst knapp für ein „Mini-Prüfungs"-Erlebnis, nicht an die
    /// vollen realen TOPIK-Zeiten angelehnt).
    static let secondsPerWord = 10
    /// Mindest-Zeitbudget, damit auch sehr kurze Prüfungen (1–2 Wörter) nicht gehetzt
    /// wirken.
    static let minimumSeconds = 20

    /// Gesamtes Zeitbudget der Prüfung in Sekunden. Skaliert mit der Wortanzahl, aber
    /// nie unter `minimumSeconds`. Eine leere Prüfung (0 Wörter) hat kein Budget – dafür
    /// zeigt der Container ohnehin den Leerzustand.
    static func duration(wordCount: Int) -> Int {
        guard wordCount > 0 else { return 0 }
        return max(minimumSeconds, wordCount * secondsPerWord)
    }

    /// Prüfungs-Score in Prozent (0…100, gerundet). Nenner ist die **gesamte** Wortzahl:
    /// bei Zeitablauf unbeantwortet gebliebene Wörter zählen wie falsch. 0 Wörter → 0 %.
    static func score(correct: Int, total: Int) -> Int {
        guard total > 0 else { return 0 }
        let clamped = min(max(0, correct), total)
        return Int((Double(clamped) / Double(total) * 100).rounded())
    }

    /// Bestehensgrenze in Prozent, grob an reale TOPIK-Grade-Grenzen angelehnt: TOPIK I
    /// (Anfänger) ist milder (~40 %), TOPIK II (Fortgeschritten) verlangt mehr (~50 %).
    /// Ohne eindeutiges Level (gemischt/keins) gilt die strengere Grenze.
    static func passMark(for level: TopikLevel?) -> Int {
        switch level {
        case .one: return 40
        case .two: return 50
        case nil: return 50
        }
    }

    /// Ob die Prüfung bestanden ist: erreichter Score ≥ Bestehensgrenze des Levels.
    static func passed(correct: Int, total: Int, level: TopikLevel?) -> Bool {
        score(correct: correct, total: total) >= passMark(for: level)
    }
}
