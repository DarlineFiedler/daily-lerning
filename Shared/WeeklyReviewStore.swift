import Foundation

enum WeeklyReviewKeys {
    static let log = "weeklyReview.log" // JSON-kodiertes WeeklyActivity
}

/// Persistenz-Keys für das selbst gesetzte Tages-/Wochenziel (in `AppGroup.defaults`).
enum GoalKeys {
    static let metric = "goal.metric" // GoalMetric.rawValue
    static let weekly = "goal.weekly" // Zielwert pro Woche (0 = aus)
    static let daily = "goal.daily" // Zielwert pro Tag (0 = aus)
}

/// Zielart des persönlichen Lernziels: entweder *geübte* oder *neu gelernte* Wörter.
/// Wird gemeinsam für Tages- und Wochenziel verwendet.
enum GoalMetric: String, CaseIterable, Identifiable {
    case practiced
    case learned

    var id: String { rawValue }
    /// Localization-Key für das Label im Einstellungs-Picker.
    var labelKey: String { "settings.goal.metric.\(rawValue)" }
}

/// Vordefinierte Zielwert-Optionen für die Einstellungs-Picker (jeweils inkl. `0` = aus).
enum GoalOptions {
    static let weekly = [0, 5, 10, 15, 20, 30, 50, 75, 100]
    static let daily = [0, 1, 2, 3, 5, 8, 10, 15, 20]
    /// Standard: kein Ziel gesetzt – die Ziel-Karte erscheint erst, wenn der Nutzer
    /// bewusst einen Wert wählt (verhindert ungefragte Karten/Badges nach Update).
    static let defaultWeekly = 0
    static let defaultDaily = 0
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

/// Ein Wochen-Aggregat für die Lernkurve (#40): geübte/neu gelernte Wörter sowie
/// richtige/falsche Antworten der Kalenderwoche ab `weekStart`. Rein abgeleitet.
struct WeekBucket: Equatable {
    let weekStart: Date
    let practiced: Int
    let newlyLearned: Int
    let correct: Int
    let wrong: Int

    /// Trefferquote in Prozent (gerundet); `nil`, wenn in der Woche nicht
    /// beantwortet wurde (verhindert eine irreführende 0 %-Linie).
    var accuracy: Int? {
        let answered = correct + wrong
        return answered == 0 ? nil : Int(round(Double(correct) / Double(answered) * 100))
    }

    /// Gab es in der Woche überhaupt Aktivität?
    var hasActivity: Bool { practiced > 0 || newlyLearned > 0 || correct + wrong > 0 }
}

/// Reiner, testbarer Aktivitäts-Log für den Wochenrückblick: pro Kalendertag ein
/// Aggregat aus den *distinct* geübten Wort-IDs, der Anzahl neu auf „Gelernt"
/// gestiegener Wörter sowie richtigen/falschen Antworten. Enthält keine Persistenz –
/// `WeeklyReviewStore` lädt/speichert ihn (analog zu [[StreakStore]] / `StreakState`).
struct WeeklyActivity: Codable, Equatable {

    /// Aggregat eines einzelnen Kalendertags.
    struct DayEntry: Codable, Equatable {
        var day: Date // Tagesanfang
        var practicedIDs: Set<UUID> // eindeutige geübte Wörter → keine Doppelzählung
        var newlyLearned: Int // Wörter, die an diesem Tag erstmals „Gelernt" wurden
        var correctCount: Int // richtig beantwortete Antworten (für Trefferquote)
        var wrongCount: Int // falsch beantwortete Antworten (für Trefferquote)

        init(day: Date, practicedIDs: Set<UUID>, newlyLearned: Int,
             correctCount: Int = 0, wrongCount: Int = 0) {
            self.day = day
            self.practicedIDs = practicedIDs
            self.newlyLearned = newlyLearned
            self.correctCount = correctCount
            self.wrongCount = wrongCount
        }

        // Migrationssicher: alte Logs (vor der Trefferquote) haben keine
        // `correctCount`/`wrongCount`-Keys – ohne dieses eigene Decoding würde der
        // synthetisierte Decoder scheitern und die gesamte Historie verwerfen.
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            day = try c.decode(Date.self, forKey: .day)
            practicedIDs = try c.decode(Set<UUID>.self, forKey: .practicedIDs)
            newlyLearned = try c.decode(Int.self, forKey: .newlyLearned)
            correctCount = try c.decodeIfPresent(Int.self, forKey: .correctCount) ?? 0
            wrongCount = try c.decodeIfPresent(Int.self, forKey: .wrongCount) ?? 0
        }
    }

    var days: [DayEntry] = []

    /// Aufbewahrungsfenster (Tage). Deckt neben dem Wochenrückblick (letzte + Vorwoche)
    /// auch die ~13 Wochen der Lernkurve (#40) und die 3-Monats-Heatmap (#54) ab.
    static let retentionDays = 91

    /// Verbucht ein geübtes Wort am `date`. `becameLearned` = das Wort ist mit
    /// dieser Antwort erstmals auf „Gelernt" gestiegen; `correct` = die Antwort war
    /// richtig (für die Trefferquote). Immutable + selbst-prunend.
    func recording(wordID: UUID, becameLearned: Bool, correct: Bool,
                   on date: Date, calendar: Calendar) -> WeeklyActivity {
        var copy = self
        let day = calendar.startOfDay(for: date)
        if let index = copy.days.firstIndex(where: { $0.day == day }) {
            copy.days[index].practicedIDs.insert(wordID)
            if becameLearned { copy.days[index].newlyLearned += 1 }
            if correct { copy.days[index].correctCount += 1 } else { copy.days[index].wrongCount += 1 }
        } else {
            copy.days.append(DayEntry(day: day,
                                      practicedIDs: [wordID],
                                      newlyLearned: becameLearned ? 1 : 0,
                                      correctCount: correct ? 1 : 0,
                                      wrongCount: correct ? 0 : 1))
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
                            newlyLearnedCount: last.newlyLearned,
                            streak: streak,
                            deltaPercent: delta)
    }

    /// Zwischenstand der LAUFENDEN Kalenderwoche (die Woche, die `date` enthält) –
    /// Basis für das Wochenziel. Nutzt dieselbe Aggregation wie der Rückblick.
    func currentWeekTotals(asOf date: Date, calendar: Calendar) -> (practiced: Int, learned: Int) {
        let t = totals(forWeekStarting: calendar.startOfWeek(for: date), calendar: calendar)
        return (t.practiced, t.newlyLearned)
    }

    /// Zwischenstand des HEUTIGEN Tages – Basis für das Tagesziel. `0/0`, wenn für den
    /// Tag noch kein Eintrag existiert.
    func dayTotals(on date: Date, calendar: Calendar) -> (practiced: Int, learned: Int) {
        let day = calendar.startOfDay(for: date)
        guard let entry = days.first(where: { $0.day == day }) else { return (0, 0) }
        return (entry.practicedIDs.count, entry.newlyLearned)
    }

    // MARK: - Serien für Statistik (Lernkurve / Heatmap)

    /// Wochenserie für die Lernkurve (#40): die letzten `weeks` Kalenderwochen
    /// (älteste zuerst), inklusive Wochen ohne Aktivität (als Nullwerte). `asOf`
    /// bestimmt die aktuelle Woche.
    func weeklySeries(weeks: Int, asOf date: Date, calendar: Calendar) -> [WeekBucket] {
        guard weeks > 0 else { return [] }
        let currentWeekStart = calendar.startOfWeek(for: date)
        return (0 ..< weeks).reversed().compactMap { offset in
            guard let start = calendar.date(byAdding: .day, value: -7 * offset, to: currentWeekStart) else { return nil }
            return totals(forWeekStarting: start, calendar: calendar)
        }
    }

    /// Tages-Übungsmengen für die Heatmap (#54): `startOfDay → Anzahl distinct
    /// geübter Wörter` für die letzten `days` Tage. Tage ohne Eintrag fehlen im
    /// Dict (der Aufrufer wertet sie als 0).
    func dailyPracticed(days count: Int, asOf date: Date, calendar: Calendar) -> [Date: Int] {
        guard count > 0 else { return [:] }
        let start = calendar.startOfDay(for: date)
        guard let cutoff = calendar.date(byAdding: .day, value: -(count - 1), to: start) else { return [:] }
        var result: [Date: Int] = [:]
        for entry in days where entry.day >= cutoff && entry.day <= start {
            result[entry.day] = entry.practicedIDs.count
        }
        return result
    }

    // MARK: - Intern

    /// Aggregiert die Kalenderwoche `[weekStart, weekStart+7)` zu einem `WeekBucket`.
    private func totals(forWeekStarting weekStart: Date, calendar: Calendar) -> WeekBucket {
        let empty = WeekBucket(weekStart: weekStart, practiced: 0, newlyLearned: 0, correct: 0, wrong: 0)
        guard let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) else { return empty }
        var ids: Set<UUID> = []
        var learned = 0
        var correct = 0
        var wrong = 0
        for entry in days where entry.day >= weekStart && entry.day < weekEnd {
            ids.formUnion(entry.practicedIDs)
            learned += entry.newlyLearned
            correct += entry.correctCount
            wrong += entry.wrongCount
        }
        return WeekBucket(weekStart: weekStart, practiced: ids.count, newlyLearned: learned,
                          correct: correct, wrong: wrong)
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
    static func record(wordID: UUID, becameLearned: Bool, correct: Bool,
                       on date: Date = .now, calendar: Calendar = .current) {
        save(load().recording(wordID: wordID, becameLearned: becameLearned, correct: correct,
                              on: date, calendar: calendar))
    }

    /// Rückblick auf die letzte abgeschlossene Woche inkl. aktuellem Streak.
    static func currentReview(asOf date: Date = .now, calendar: Calendar = .current) -> WeeklyReview {
        load().lastCompletedWeekReview(
            asOf: date,
            calendar: calendar,
            streak: StreakStore.displayStreak(asOf: date, calendar: calendar)
        )
    }

    /// Fortschritt der laufenden Woche gegen das Wochenziel (Anzahl gemäß `metric`).
    static func weekProgress(for metric: GoalMetric, asOf date: Date = .now, calendar: Calendar = .current) -> Int {
        value(of: metric, in: load().currentWeekTotals(asOf: date, calendar: calendar))
    }

    /// Fortschritt des heutigen Tages gegen das Tagesziel (Anzahl gemäß `metric`).
    static func dayProgress(for metric: GoalMetric, asOf date: Date = .now, calendar: Calendar = .current) -> Int {
        value(of: metric, in: load().dayTotals(on: date, calendar: calendar))
    }

    /// Wochenserie für die Lernkurve (#40) – die letzten `weeks` Kalenderwochen.
    static func weeklySeries(weeks: Int, asOf date: Date = .now, calendar: Calendar = .current) -> [WeekBucket] {
        load().weeklySeries(weeks: weeks, asOf: date, calendar: calendar)
    }

    /// Tages-Übungsmengen für die Heatmap (#54) – die letzten `days` Tage.
    static func dailyPracticed(days: Int, asOf date: Date = .now, calendar: Calendar = .current) -> [Date: Int] {
        load().dailyPracticed(days: days, asOf: date, calendar: calendar)
    }

    private static func value(of metric: GoalMetric, in totals: (practiced: Int, learned: Int)) -> Int {
        switch metric {
        case .practiced: return totals.practiced
        case .learned: return totals.learned
        }
    }

    // MARK: - Batch (Übungs-Hotpath)

    /// Lädt den persistierten Log für Aufrufer, die mehrere Buchungen im Speicher
    /// sammeln und gebündelt via `saveActivity(_:)` zurückschreiben – so entfällt der
    /// volle JSON-Decode/Encode je Übungsantwort.
    ///
    /// Load-once/flush-later ist nur sicher, solange während der Sammelphase kein
    /// zweiter Schreiber den Log anfasst (sonst überschreibt das spätere `saveActivity`
    /// dessen Änderung). Aktuell ist die laufende Übungssession der einzige Schreiber –
    /// diese Invariante halten, falls je ein weiterer Aufrufer dazukommt.
    static func loadActivity() -> WeeklyActivity { load() }

    /// Schreibt einen im Speicher gesammelten Log gebündelt zurück.
    static func saveActivity(_ activity: WeeklyActivity) { save(activity) }

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
