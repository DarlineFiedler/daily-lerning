import Foundation

/// Wählt das „Wort des Tages" – stabil pro Kalendertag.
///
/// Bevorzugt Wörter, die schon im Lernprozess sind (Status ≠ `.new`, also „Am Lernen",
/// „Fast gelernt" oder „Gelernt"). Gibt es davon noch keins (z.B. frische Installation mit
/// ausschließlich neuen Wörtern), fällt die Auswahl auf alle Wörter zurück, damit die
/// Home-Karte sichtbar bleibt. `now` ist injizierbar (Tests).
enum WordOfDay {
    static func pick(from vocabs: [Vocab], now: Date = .now) -> Vocab? {
        // Bewusst nicht `inProgress` genannt: Anders als in `DailyPlan` zählt hier auch
        // „Gelernt" dazu (alles außer „Neu"), nicht nur „Am Lernen"/„Fast gelernt".
        let started = vocabs.filter { $0.status != .new }
        let pool = started.isEmpty ? vocabs : started
        guard !pool.isEmpty else { return nil }
        // Tages-Index = Anzahl lokaler Kalendertage seit einem festen Referenztag.
        // Bewusst NICHT `ordinality(of: .day, in: .era)`: das rechnet intern in GMT und legt
        // den Tageswechsel dadurch je nach Zeitzone versetzt (nicht um lokale Mitternacht).
        let calendar = Calendar.current
        let epoch = calendar.startOfDay(for: Date(timeIntervalSinceReferenceDate: 0))
        let today = calendar.startOfDay(for: now)
        let day = calendar.dateComponents([.day], from: epoch, to: today).day ?? 0
        return pool[day % pool.count]
    }
}
