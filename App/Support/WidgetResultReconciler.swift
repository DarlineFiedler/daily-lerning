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

        var changed = false
        for result in results {
            guard let vocab = byID[result.wordID] else { continue }
            vocab.registerResult(correct: result.correct, now: result.date)
            changed = true
        }
        if changed { context.saveOrLog() }
        return changed
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
