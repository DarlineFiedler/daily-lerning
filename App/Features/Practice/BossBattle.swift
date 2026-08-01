import Foundation

/// Reine, testbare Kampf-Logik für den „Endgegner"-Modus (Issue #89). Kein eigener
/// Zustand: alle Werte leiten sich aus der laufenden `PracticeSession` ab
/// (`total`, `correctCount`, `wrongCount`). Der Boss hat so viele Trefferpunkte wie
/// die Runde Wörter hat; jede richtige Antwort ist ein Treffer, jede falsche kostet
/// die Spielerin ein Leben. Gehen die Leben aus, gewinnt der Boss.
struct BossBattle: Equatable {
    /// Boss-Trefferpunkte insgesamt = Anzahl der Wörter in der Runde.
    let maxHP: Int
    /// Bisher richtige Antworten (= gelandete Treffer).
    let correct: Int
    /// Bisher falsche Antworten (= verlorene Leben / Gegenschläge).
    let wrong: Int

    init(total: Int, correct: Int, wrong: Int) {
        maxHP = max(0, total)
        self.correct = max(0, correct)
        self.wrong = max(0, wrong)
    }

    /// Erlaubte Fehler, bevor der Boss gewinnt. Skaliert mit der Rundengröße
    /// (~ein Drittel der Wörter), aber mindestens 3 – so bleiben auch kurze Runden
    /// fair. Bei einer leeren Runde (0 Wörter) gibt es nichts zu kämpfen (0 Leben).
    static func maxLives(forTotalWords total: Int) -> Int {
        guard total > 0 else { return 0 }
        return max(3, Int((Double(total) * 0.34).rounded(.up)))
    }

    var maxLives: Int { Self.maxLives(forTotalWords: maxHP) }

    /// Verbleibende Boss-Trefferpunkte – sinkt mit jedem Treffer (richtige Antwort).
    var currentHP: Int { max(0, maxHP - correct) }

    /// Boss-HP als Anteil 0…1 (für die HP-Leiste). 0 Wörter → leer.
    var hpFraction: Double {
        maxHP == 0 ? 0 : Double(currentHP) / Double(maxHP)
    }

    /// Verbleibende Leben der Spielerin.
    var livesRemaining: Int { max(0, maxLives - wrong) }

    /// Leben als Anteil 0…1 (für die Herz-/Leben-Anzeige).
    var livesFraction: Double {
        maxLives == 0 ? 0 : Double(livesRemaining) / Double(maxLives)
    }

    /// Zu viele Fehler → Spielerin k.o., der Boss gewinnt. In einer leeren Runde
    /// (0 Leben) gibt es keinen Kampf und damit keine Niederlage.
    var isPlayerDefeated: Bool { maxLives > 0 && livesRemaining == 0 }

    /// Am Rundenende: hat die Spielerin gewonnen? (Runde durchgestanden, ohne k.o.
    /// zu gehen.) Nur nach Abschluss der Runde aussagekräftig.
    var playerWon: Bool { !isPlayerDefeated }
}
