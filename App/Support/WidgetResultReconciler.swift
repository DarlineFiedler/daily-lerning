import Foundation
import SwiftData

/// Spielt die vom interaktiven Widget verbuchten Ergebnisse ([[WidgetResultQueue]]) in den
/// SwiftData-Store ein. Das Widget selbst kann die DB nicht erreichen (siehe
/// [[RegisterWidgetResultIntent]]); dieser Reconciler läuft in der App und schließt die Lücke
/// über dieselbe `Vocab.registerResult`-Logik wie der normale Lernfluss.
@MainActor
enum WidgetResultReconciler {

    /// Wendet die gepufferten Ergebnisse auf den Store an. Gibt zurück, ob tatsächlich etwas
    /// verbucht wurde (unbekannte Wort-IDs – z.B. zwischenzeitlich gelöscht – werden
    /// übersprungen). Reine Anwendung ohne Datei-I/O, damit sie isoliert testbar bleibt.
    @discardableResult
    static func apply(_ results: [PendingWidgetResult], context: ModelContext) -> Bool {
        guard !results.isEmpty else { return false }
        let vocabs = (try? context.fetch(FetchDescriptor<Vocab>())) ?? []
        // UUIDs sind eindeutig; `uniquingKeysWith` nur als Absicherung gegen einen theoretischen
        // Doppel-Eintrag, damit der Lookup-Aufbau nicht crasht.
        let byID = Dictionary(vocabs.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        // Ergebnisse chronologisch verarbeiten: Das Widget kann über mehrere Tage puffern, und
        // die Streak-/Wochen-Buchung hängt an der Tagesreihenfolge.
        let ordered = results.sorted { $0.date < $1.date }
        let calendar = Calendar.current
        // Wochen-Log EINMAL laden und gebündelt zurückschreiben (wie der Übungs-Hotpath in
        // [[PracticeSession]]), statt pro Ergebnis zu de/encoden.
        var weekly = WeeklyReviewStore.loadActivity()
        var activeDays: Set<Date> = []

        var changed = false
        for result in ordered {
            guard let vocab = byID[result.wordID] else { continue }
            // Erstaufstieg auf „Gelernt" VOR `registerResult` bestimmen (das setzt das Flag) –
            // so zählt nur der Erstaufstieg als „neu gelernt" (analog PracticeSession.record).
            let wasEverLearned = vocab.everReachedLearned
            let before = vocab.status
            vocab.registerResult(correct: result.correct, now: result.date)
            let becameLearned = !wasEverLearned && before != .learned && vocab.status == .learned
            // Wochenrückblick/Ziel-Fortschritt füttern (distinct Wort + Trefferquote).
            weekly = weekly.recording(wordID: vocab.id, becameLearned: becameLearned,
                                      correct: result.correct, on: result.date, calendar: calendar)
            activeDays.insert(calendar.startOfDay(for: result.date))
            changed = true
        }

        guard changed else { return false }
        // Streak je betroffenem Kalendertag verbuchen (idempotent pro Tag, chronologisch, damit
        // überbrückte Lücken korrekt mit Jokern aufgelöst werden). Damit zählt auch ein reiner
        // Widget-Tag für die Streak – sonst reißt sie trotz Aktivität ab.
        for day in activeDays.sorted() {
            StreakStore.registerActivity(on: day, calendar: calendar)
        }
        WeeklyReviewStore.saveActivity(weekly)
        context.saveOrLog()
        return true
    }

    /// Lädt die Queue, leert sie und spielt sie ein. Gibt zurück, ob etwas verbucht wurde –
    /// der Aufrufer ([[AppContentRefresh]]) frischt dann Widget/Badge auch am selben Tag auf.
    @discardableResult
    static func drain(context: ModelContext) -> Bool {
        let pending = WidgetResultQueue.load()
        guard !pending.isEmpty else { return false }
        // Zuerst leeren, dann anwenden: So kann ein Fehler beim Anwenden nicht dazu führen, dass
        // dieselben Ergebnisse beim nächsten Drain erneut verbucht werden (Doppelzählung).
        WidgetResultQueue.clear()
        return apply(pending, context: context)
    }
}
