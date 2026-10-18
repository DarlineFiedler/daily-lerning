import Foundation
import OSLog
import SwiftData

private let reconcilerLog = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.darlinefiedler.DailyHangul",
    category: "widgetReconciler"
)

/// Spielt die vom interaktiven Widget verbuchten Ergebnisse ([[WidgetResultQueue]]) in den
/// SwiftData-Store ein. Das Widget selbst kann die DB nicht erreichen (siehe
/// [[RegisterWidgetResultIntent]]); dieser Reconciler läuft in der App und schließt die Lücke
/// über dieselbe `Vocab.registerResult`-Logik wie der normale Lernfluss.
@MainActor
enum WidgetResultReconciler {

    /// Ergebnis einer Einspielung – steuert in [[drain]], ob die Queue geleert werden darf.
    enum Outcome: Equatable {
        /// Nichts Anwendbares (leer oder nur unbekannte/gelöschte IDs) → Queue darf geleert werden.
        case nothing
        /// Änderungen erfolgreich gespeichert → Queue darf geleert werden.
        case persisted
        /// DB-Save fehlgeschlagen und zurückgerollt → Queue BEHALTEN (sauberer Retry beim nächsten Drain).
        case saveFailed
    }

    /// Wendet die gepufferten Ergebnisse auf den Store an. Reine Anwendung ohne Datei-I/O der
    /// Queue, damit sie isoliert testbar bleibt.
    ///
    /// Reihenfolge ist bewusst: erst die (idempotenten) Vokabel-Änderungen in die DB speichern,
    /// und NUR bei erfolgreichem Save die nicht-idempotenten Streak-/Wochen-Zähler in die Defaults
    /// schreiben. Scheitert der Save, wird der Kontext zurückgerollt und nichts in die Defaults
    /// geschrieben – so kann ein Retry (die Queue bleibt dann erhalten) nicht doppelt zählen.
    @discardableResult
    static func apply(_ results: [PendingWidgetResult], context: ModelContext,
                      now: Date = .now) -> Outcome {
        guard !results.isEmpty else { return .nothing }
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
            // Tap-Datum in der Zukunft (Uhr-Schieflage beim Tippen) auf „jetzt" kappen – sonst
            // würde `WeeklyActivity.recording` die Historie relativ zu einem Zukunftsdatum prunen
            // und echte aktuelle Einträge verwerfen.
            let effectiveDate = min(result.date, now)
            // Erstaufstieg auf „Gelernt" VOR `registerResult` bestimmen (das setzt das Flag) –
            // so zählt nur der Erstaufstieg als „neu gelernt" (analog PracticeSession.record).
            let wasEverLearned = vocab.everReachedLearned
            let before = vocab.status
            vocab.registerResult(correct: result.correct, now: effectiveDate)
            let becameLearned = !wasEverLearned && before != .learned && vocab.status == .learned
            // Wochenrückblick/Ziel-Fortschritt füttern (distinct Wort + Trefferquote).
            weekly = weekly.recording(wordID: vocab.id, becameLearned: becameLearned,
                                      correct: result.correct, on: effectiveDate, calendar: calendar)
            activeDays.insert(calendar.startOfDay(for: effectiveDate))
            changed = true
        }

        guard changed else { return .nothing }

        // DB zuerst speichern. Erst danach die nicht-idempotenten Defaults (Streak/Wochen-Log)
        // schreiben – scheitert der Save, alles zurückrollen und nichts in die Defaults schreiben,
        // damit ein Retry sauber von vorn beginnt (kein doppeltes registerResult/Zählen).
        do {
            try context.save()
        } catch {
            reconcilerLog.error("Widget-Reconcile-Save fehlgeschlagen: \(error.localizedDescription, privacy: .public)")
            context.rollback()
            return .saveFailed
        }

        // Joker-Anker VOR dem Verbuchen (evtl. zurückdatierter) Widget-Tage auf die aktuelle Woche
        // setzen. Sonst könnte ein brandneuer Nutzer (noch kein weekAnchor), dessen erste Aktivität
        // ein über mehrere Wochen gepufferter Widget-Stapel ist, rückwirkend Wochen-Joker bis zum
        // Cap kassieren. `settle` ist idempotent, wenn der Anker schon auf dieser Woche steht.
        StreakStore.settle(on: now, calendar: calendar)
        // Streak je betroffenem Kalendertag verbuchen (idempotent pro Tag, chronologisch, damit
        // überbrückte Lücken korrekt mit Jokern aufgelöst werden). Damit zählt auch ein reiner
        // Widget-Tag für die Streak – sonst reißt sie trotz Aktivität ab.
        for day in activeDays.sorted() {
            StreakStore.registerActivity(on: day, calendar: calendar)
        }
        WeeklyReviewStore.saveActivity(weekly)
        return .persisted
    }

    /// Lädt die Queue, spielt sie ein und leert sie – aber NUR, wenn die Einspielung nicht an
    /// einem Save-Fehler gescheitert ist (dann bleibt die Queue für einen sauberen Retry stehen).
    /// Gibt zurück, ob tatsächlich etwas verbucht wurde – der Aufrufer ([[AppContentRefresh]])
    /// frischt dann Widget/Badge auch am selben Tag auf.
    @discardableResult
    static func drain(context: ModelContext, now: Date = .now) -> Bool {
        let pending = WidgetResultQueue.load()
        guard !pending.isEmpty else { return false }
        let outcome = apply(pending, context: context, now: now)
        // Bei `.saveFailed` die Queue BEHALTEN (Retry); sonst leeren – auch bei `.nothing`
        // (nur unbekannte/veraltete IDs), damit solche Einträge nicht endlos auflaufen.
        if outcome != .saveFailed { WidgetResultQueue.clear() }
        return outcome == .persisted
    }
}
