import SwiftUI
import WidgetKit

/// Ein Zeitpunkt-Eintrag für das Streak-Widget.
struct StreakEntry: TimelineEntry {
    let date: Date
    let model: StreakWidgetModel
}

/// Liefert den aktuellen Streak-/Ziel-Stand aus dem geteilten App-Group-Zustand
/// (siehe [[StreakWidgetModel]]). Streak und Ziel ändern sich nur bei App-Nutzung,
/// daher genügt EIN Eintrag mit Reload zum nächsten Tagesbeginn – dann „läuft" ein
/// abgelaufener Streak visuell ab. Zusätzlich lädt die App die Timeline nach
/// relevanten Änderungen (Übungsrunde, Zielanpassung) aktiv neu.
struct StreakTimelineProvider: TimelineProvider {

    func placeholder(in context: Context) -> StreakEntry {
        StreakEntry(date: .now, model: StreakWidgetModel(streak: 7, longest: 12, goal: nil))
    }

    func getSnapshot(in context: Context, completion: @escaping (StreakEntry) -> Void) {
        completion(StreakEntry(date: .now, model: StreakWidgetModel.current()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StreakEntry>) -> Void) {
        let entry = StreakEntry(date: .now, model: StreakWidgetModel.current())
        let nextMidnight = Calendar.current.nextDate(
            after: .now,
            matching: DateComponents(hour: 0, minute: 0, second: 0),
            matchingPolicy: .nextTime
        ) ?? Calendar.current.date(byAdding: .hour, value: 6, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(nextMidnight)))
    }
}
