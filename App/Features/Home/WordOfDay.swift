import Foundation

/// Wählt das „Wort des Tages" – stabil pro Kalendertag.
///
/// Bevorzugt Wörter, die schon im Lernprozess sind (Status ≠ `.new`, also „Am Lernen",
/// „Fast gelernt" oder „Gelernt"). Gibt es davon noch keins (z.B. frische Installation mit
/// ausschließlich neuen Wörtern), fällt die Auswahl auf alle Wörter zurück, damit die
/// Home-Karte sichtbar bleibt. `now` ist injizierbar (Tests).
enum WordOfDay {
    static func pick(from vocabs: [Vocab], now: Date = .now) -> Vocab? {
        let inProgress = vocabs.filter { $0.status != .new }
        let pool = inProgress.isEmpty ? vocabs : inProgress
        guard !pool.isEmpty else { return nil }
        let day = Calendar.current.ordinality(of: .day, in: .era, for: now) ?? 0
        return pool[day % pool.count]
    }
}
