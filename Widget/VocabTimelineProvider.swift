import SwiftUI
import WidgetKit

/// Ein Zeitpunkt-Eintrag für das Widget.
struct VocabEntry: TimelineEntry {
    let date: Date
    let word: WidgetWord?
    let settings: WidgetSettings
    /// Wurde das gezeigte Wort gerade im Widget verbucht? `nil` = normale Ansicht mit
    /// „Gewusst"/„Nochmal"-Buttons; sonst zeigt die Karte kurz die Bestätigung (`true` =
    /// „Gewusst", `false` = „Nochmal"). Nur der aktuelle Slot wird so markiert – beim nächsten
    /// Wort kommen die Buttons zurück (siehe `getTimeline`).
    var justAnsweredCorrect: Bool?
}

/// Baut eine Timeline, die im gewählten Minuten-Intervall durch die aktivierten
/// Wörter rotiert. Die Einträge werden vorab für ~24h erzeugt, sodass die Rotation
/// ohne ständiges Neuladen innerhalb des WidgetKit-Budgets funktioniert.
struct VocabTimelineProvider: TimelineProvider {

    func placeholder(in context: Context) -> VocabEntry {
        VocabEntry(
            date: .now,
            word: WidgetWord(id: UUID(), word: "가다", meaning: "gehen"),
            settings: WidgetSettings()
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (VocabEntry) -> Void) {
        let snapshot = WidgetSnapshot.load()
        completion(VocabEntry(date: .now, word: snapshot.words.first, settings: snapshot.settings))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<VocabEntry>) -> Void) {
        let snapshot = WidgetSnapshot.load()
        let settings = snapshot.settings
        let words = snapshot.words

        guard !words.isEmpty else {
            let entry = VocabEntry(date: .now, word: nil, settings: settings)
            let refresh = Calendar.current.date(byAdding: .hour, value: 1, to: .now) ?? .now
            completion(Timeline(entries: [entry], policy: .after(refresh)))
            return
        }

        let interval = max(settings.intervalMinutes, 1)
        let perDay = (24 * 60) / interval
        let count = min(max(perDay, words.count), 200)

        // Zeit-verankerte Rotation: der angezeigte Slot folgt aus der echten Uhrzeit
        // (nicht aus dem Build-Zeitpunkt), daher springt das Widget beim App-Öffnen
        // nicht mehr auf Wort 1 zurück.
        let n = words.count
        let anchor = settings.rotationAnchor
        let seed = settings.rotationSeed
        let secondsPerSlot = Double(interval * 60)
        let elapsed = Date().timeIntervalSince(anchor)
        let nowSlot = max(0, Int((elapsed / secondsPerSlot).rounded(.down)))

        var entries: [VocabEntry] = []
        // Permutation nur einmal pro Zyklus aufbauen statt für jeden Slot neu.
        var cachedCycle = -1
        var permutation: [Int] = []
        for j in 0 ..< count {
            let slot = nowSlot + j
            let date = anchor.addingTimeInterval(Double(slot) * secondsPerSlot)
            let idx: Int
            if n > 1 {
                let cycle = slot / n
                if cycle != cachedCycle {
                    cachedCycle = cycle
                    permutation = WidgetRotation.seededPermutation(
                        wordCount: n,
                        seed: WidgetRotation.cycleSeed(cycle, seed: seed)
                    )
                }
                idx = permutation[slot % n]
            } else {
                idx = 0
            }
            entries.append(VocabEntry(date: date, word: words[idx], settings: settings))
        }

        // Bestätigung: Wurde das Wort des aktuellen Slots gerade im Widget verbucht, zeigt genau
        // dieser (erste) Eintrag „Verbucht ✓" statt der Buttons. Das verhindert ein Doppel-
        // Verbuchen derselben sichtbaren Karte; beim nächsten Slot (= nächstes Wort) rendern die
        // Buttons wieder. Bezug ist der Slot-Beginn, damit eine Antwort aus einem früheren Slot
        // nicht nachwirkt.
        if let last = WidgetResultQueue.load().last,
           let current = entries.first,
           last.wordID == current.word?.id {
            let slotStart = anchor.addingTimeInterval(Double(nowSlot) * secondsPerSlot)
            if last.date >= slotStart {
                entries[0].justAnsweredCorrect = last.correct
            }
        }

        completion(Timeline(entries: entries, policy: .atEnd))
    }
}
