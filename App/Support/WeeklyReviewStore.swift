import Foundation

enum WeeklyReviewKeys {
    static let log = "weeklyReview.log" // JSON-kodiertes WeeklyActivity
}

/// Zusammenfassung einer abgeschlossenen Kalenderwoche – rein abgeleitet, für die
/// Home-Karte. `deltaPercent` vergleicht die geübten Wörter mit der Vorwoche
/// (`nil`, wenn es keine Vorwochen-Daten gibt, z.B. nach Neuinstallation).
struct WeeklyReview: Equatable {
    let weekStart: Date
    let practicedCount: Int
    let newlyLearnedCount: Int
    let streak: Int
    let deltaPercent: Int?

    /// Gab es in der betrachteten Woche überhaupt Aktivität? Steuert, ob die
    /// Home-Karte gezeigt wird (kein leerer Rückblick bei Neuinstallation).
    var hasActivity: Bool { practicedCount > 0 || newlyLearnedCount > 0 }
}

/// Reiner, testbarer Aktivitäts-Log für den Wochenrückblick: pro Kalendertag ein
/// Aggregat aus den *distinct* geübten Wort-IDs und der Anzahl neu auf „Gelernt"
/// gestiegener Wörter. Enthält keine Persistenz – `WeeklyReviewStore` lädt/speichert
/// ihn (analog zu [[StreakStore]] / `StreakState`).
struct WeeklyActivity: Codable, Equatable {

    /// Aggregat eines einzelnen Kalendertags.
    struct DayEntry: Codable, Equatable {
        var day: Date // Tagesanfang
        var practicedIDs: Set<UUID> // eindeutige geübte Wörter → keine Doppelzählung
        var newlyLearned: Int // Wörter, die an diesem Tag erstmals „Gelernt" wurden
    }

    var days: [DayEntry] = []

    /// Aufbewahrungsfenster (Tage). Muss die letzte abgeschlossene Woche und die
    /// Vorwoche (für das Delta) abdecken; 28 Tage lassen dafür Puffer.
    static let retentionDays = 28

    /// Verbucht ein geübtes Wort am `date`. `becameLearned` = das Wort ist mit
    /// dieser Antwort erstmals auf „Gelernt" gestiegen. Immutable + selbst-prunend.
    func recording(wordID: UUID, becameLearned: Bool, on date: Date, calendar: Calendar) -> WeeklyActivity {
        var copy = self
        let day = calendar.startOfDay(for: date)
        if let index = copy.days.firstIndex(where: { $0.day == day }) {
            copy.days[index].practicedIDs.insert(wordID)
            if becameLearned { copy.days[index].newlyLearned += 1 }
        } else {
            copy.days.append(DayEntry(day: day,
                                      practicedIDs: [wordID],
                                      newlyLearned: becameLearned ? 1 : 0))
        }
        copy.pruneHistory(before: date, calendar: calendar)
        return copy
    }

    /// Rückblick auf die letzte ABGESCHLOSSENE Kalenderwoche (die Woche vor der,
    /// die `date` enthält). `streak` wird von außen (StreakStore) hereingereicht.
    func lastCompletedWeekReview(asOf date: Date, calendar: Calendar, streak: Int) -> WeeklyReview {
        let currentWeekStart = calendar.startOfWeek(for: date)
        let lastWeekStart = calendar.date(byAdding: .day, value: -7, to: currentWeekStart) ?? currentWeekStart
        let prevWeekStart = calendar.date(byAdding: .day, value: -14, to: currentWeekStart) ?? currentWeekStart

        let last = totals(forWeekStarting: lastWeekStart, calendar: calendar)
        let prev = totals(forWeekStarting: prevWeekStart, calendar: calendar)

        var delta: Int?
        if prev.practiced > 0 {
            let change = Double(last.practiced - prev.practiced) / Double(prev.practiced) * 100
            delta = Int(change.rounded())
        }

        return WeeklyReview(weekStart: lastWeekStart,
                            practicedCount: last.practiced,
                            newlyLearnedCount: last.learned,
                            streak: streak,
                            deltaPercent: delta)
    }

    // MARK: - Intern

    /// Aggregiert die Kalenderwoche `[weekStart, weekStart+7)`.
    private func totals(forWeekStarting weekStart: Date, calendar: Calendar) -> (practiced: Int, learned: Int) {
        guard let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) else { return (0, 0) }
        var ids: Set<UUID> = []
        var learned = 0
        for entry in days where entry.day >= weekStart && entry.day < weekEnd {
            ids.formUnion(entry.practicedIDs)
            learned += entry.newlyLearned
        }
        return (ids.count, learned)
    }

    /// Entfernt Tageseinträge, die älter als `retentionDays` sind.
    private mutating func pruneHistory(before date: Date, calendar: Calendar) {
        let start = calendar.startOfDay(for: date)
        guard let cutoff = calendar.date(byAdding: .day, value: -Self.retentionDays, to: start) else { return }
        days.removeAll { $0.day < cutoff }
    }
}

/// Persistiert den Wochen-Aktivitäts-Log im geteilten App-Group-`UserDefaults`
/// (JSON), analog zu [[StreakStore]]. Kein SwiftData-Modell/Migration nötig –
/// die Tages-Aggregate leben, wie der Streak-Verlauf, in den Defaults.
enum WeeklyReviewStore {
    private static var d: UserDefaults { AppGroup.defaults }

    /// Verbucht ein geübtes Wort. Bei jeder Übungsantwort aufrufen (idempotent
    /// bzgl. distinct Wörtern pro Tag). `becameLearned` markiert den Erstaufstieg
    /// auf „Gelernt".
    static func record(wordID: UUID, becameLearned: Bool, on date: Date = .now, calendar: Calendar = .current) {
        save(load().recording(wordID: wordID, becameLearned: becameLearned, on: date, calendar: calendar))
    }

    /// Rückblick auf die letzte abgeschlossene Woche inkl. aktuellem Streak.
    static func currentReview(asOf date: Date = .now, calendar: Calendar = .current) -> WeeklyReview {
        load().lastCompletedWeekReview(
            asOf: date,
            calendar: calendar,
            streak: StreakStore.displayStreak(asOf: date, calendar: calendar)
        )
    }

    // MARK: - Laden / Speichern

    private static func load() -> WeeklyActivity {
        guard let data = d.data(forKey: WeeklyReviewKeys.log),
              let decoded = try? JSONDecoder().decode(WeeklyActivity.self, from: data)
        else { return WeeklyActivity() }
        return decoded
    }

    private static func save(_ activity: WeeklyActivity) {
        guard let data = try? JSONEncoder().encode(activity) else { return }
        d.set(data, forKey: WeeklyReviewKeys.log)
    }
}
