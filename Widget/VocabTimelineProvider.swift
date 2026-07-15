import WidgetKit
import SwiftUI

/// Ein Zeitpunkt-Eintrag für das Widget.
struct VocabEntry: TimelineEntry {
    let date: Date
    let word: WidgetWord?
    let settings: WidgetSettings
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

        var entries: [VocabEntry] = []
        let start = Date()
        for i in 0..<count {
            let date = Calendar.current.date(byAdding: .minute, value: i * interval, to: start) ?? start
            let word = words[i % words.count]
            entries.append(VocabEntry(date: date, word: word, settings: settings))
        }

        completion(Timeline(entries: entries, policy: .atEnd))
    }
}
