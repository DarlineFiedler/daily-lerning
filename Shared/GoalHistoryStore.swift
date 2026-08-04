import Foundation

enum GoalHistoryKeys {
    static let log = "goal.history" // JSON-kodierte GoalHistory
}

/// Reine, testbare Historie des selbst gesetzten Tages-/Wochenziels: pro Kalendertag
/// ein Snapshot der an dem Tag geltenden Zielwerte (Tages-/Wochenziel + Metrik).
/// Enthält keine Persistenz – `GoalHistoryStore` lädt/speichert sie (analog zu
/// [[WeeklyReviewStore]] / [[StreakStore]]).
///
/// Nötig, weil das aktuelle Ziel (`GoalKeys`) nur als Einzelwert gespeichert wird – ohne
/// diese Historie ließe sich später nicht mehr rekonstruieren, welches Ziel an einem
/// bestimmten Tag galt (der Nutzer kann die Anzahl jederzeit ändern).
struct GoalHistory: Codable, Equatable {

    /// Ziel-Snapshot eines einzelnen Kalendertags.
    struct Entry: Codable, Equatable {
        var day: Date // Tagesanfang
        var dailyTarget: Int // an dem Tag geltendes Tagesziel (0 = aus)
        var weeklyTarget: Int // an dem Tag geltendes Wochenziel (0 = aus)
        var metricRaw: String // GoalMetric.rawValue an dem Tag

        init(day: Date, dailyTarget: Int, weeklyTarget: Int, metricRaw: String) {
            self.day = day
            self.dailyTarget = dailyTarget
            self.weeklyTarget = weeklyTarget
            self.metricRaw = metricRaw
        }

        // Migrationssicher: fehlende Felder in Alt-Logs fallen auf neutrale Werte
        // zurück, statt die gesamte Historie beim Decodieren zu verwerfen.
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            day = try c.decode(Date.self, forKey: .day)
            dailyTarget = try c.decodeIfPresent(Int.self, forKey: .dailyTarget) ?? 0
            weeklyTarget = try c.decodeIfPresent(Int.self, forKey: .weeklyTarget) ?? 0
            metricRaw = try c.decodeIfPresent(String.self, forKey: .metricRaw) ?? GoalMetric.practiced.rawValue
        }
    }

    var days: [Entry] = []

    /// Aufbewahrungsfenster (Tage) – deckungsgleich mit dem Aktivitäts-Log, damit
    /// Kalender/Statistik über denselben Zeitraum auswertbar bleiben.
    static let retentionDays = 91

    /// Schreibt den heute geltenden Ziel-Snapshot. Idempotent pro Kalendertag –
    /// mehrfache Aufrufe am selben Tag überschreiben den Eintrag, damit er den
    /// aktuellen Endstand (z.B. nach einer Ziel-Änderung) widerspiegelt. An Tagen ohne
    /// aktives Ziel (weder Tages- noch Wochenziel) wird kein reiner Null-Eintrag
    /// angelegt. Immutable + selbst-prunend.
    func recordingSnapshot(dailyTarget: Int, weeklyTarget: Int, metric: GoalMetric,
                           on date: Date, calendar: Calendar) -> GoalHistory {
        var copy = self
        let day = calendar.startOfDay(for: date)
        let existingIndex = copy.days.firstIndex { $0.day == day }
        // Ohne aktives Ziel und ohne bestehenden Eintrag nichts aufzeichnen (spart reine
        // Null-Einträge an ziel-losen Tagen). Ein vorhandener Eintrag wird dagegen weiter
        // aktualisiert, damit ein auf 0 zurückgesetztes Ziel den Tag korrekt „ausschaltet".
        if dailyTarget > 0 || weeklyTarget > 0 || existingIndex != nil {
            let entry = Entry(day: day, dailyTarget: dailyTarget,
                              weeklyTarget: weeklyTarget, metricRaw: metric.rawValue)
            if let existingIndex {
                copy.days[existingIndex] = entry
            } else {
                copy.days.append(entry)
            }
        }
        copy.pruneHistory(before: date, calendar: calendar)
        return copy
    }

    /// Ziel-Snapshot eines Tages, oder `nil` wenn für den Tag keiner existiert.
    func entry(on date: Date, calendar: Calendar) -> Entry? {
        let day = calendar.startOfDay(for: date)
        return days.first { $0.day == day }
    }

    /// Jüngster Ziel-Snapshot innerhalb der Kalenderwoche ab `weekStart` – die
    /// Grundlage für das an dem Zeitraum geltende Wochenziel. `nil`, wenn die Woche
    /// keinen Eintrag hat.
    func latestEntry(inWeekStarting weekStart: Date, calendar: Calendar) -> Entry? {
        guard let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) else { return nil }
        return days.filter { $0.day >= weekStart && $0.day < weekEnd }.max { $0.day < $1.day }
    }

    /// Entfernt Einträge, die älter als `retentionDays` sind.
    private mutating func pruneHistory(before date: Date, calendar: Calendar) {
        let start = calendar.startOfDay(for: date)
        guard let cutoff = calendar.date(byAdding: .day, value: -Self.retentionDays, to: start) else { return }
        days.removeAll { $0.day < cutoff }
    }
}

/// Rein abgeleitete Ziel-Statistik: kombiniert die Tages-Aktivität ([[WeeklyReviewStore]])
/// mit der Ziel-Historie (`GoalHistory`) zu den Kennzahlen für den Ziel-Statistik-Screen
/// (Kalender-Färbung, Ziel-Streak, Erfüllungsquote, Wochen-Stern). Testbar durch injizierte
/// Daten; für die App via `GoalStats.current()` aus den Stores geladen.
struct GoalStats {
    let activity: WeeklyActivity
    let history: GoalHistory
    /// Aktuell eingestellte Werte – Rückfall für Tage/Wochen ohne Historie-Eintrag
    /// (z.B. Vergangenheit vor Einführung der Historie).
    let currentDailyTarget: Int
    let currentWeeklyTarget: Int
    let currentMetric: GoalMetric
    let calendar: Calendar

    /// Erreichungs-Status eines Kalendertags gegen sein Tagesziel.
    enum DayStatus {
        case reached // Tageswert ≥ Tagesziel
        case partial // Aktivität vorhanden, aber Ziel nicht erreicht
        case missed // kein/zu wenig – Ziel galt, wurde aber verfehlt
        case noGoal // an dem Tag war kein Tagesziel gesetzt
        case upcoming // Tag liegt in der Zukunft
    }

    init(activity: WeeklyActivity, history: GoalHistory,
         currentDailyTarget: Int, currentWeeklyTarget: Int,
         currentMetric: GoalMetric, calendar: Calendar = .current) {
        self.activity = activity
        self.history = history
        self.currentDailyTarget = currentDailyTarget
        self.currentWeeklyTarget = currentWeeklyTarget
        self.currentMetric = currentMetric
        self.calendar = calendar
    }

    // MARK: - Tageswerte

    /// An dem Tag geltendes Tagesziel (aus der Historie, sonst aktueller Wert).
    func dailyTarget(on day: Date) -> Int {
        history.entry(on: day, calendar: calendar)?.dailyTarget ?? currentDailyTarget
    }

    /// An dem Tag geltende Metrik (geübte vs. neu gelernte Wörter).
    func metric(on day: Date) -> GoalMetric {
        guard let raw = history.entry(on: day, calendar: calendar)?.metricRaw,
              let metric = GoalMetric(rawValue: raw) else { return currentMetric }
        return metric
    }

    /// Erreichter Tageswert gemäß der an dem Tag geltenden Metrik.
    func value(on day: Date) -> Int {
        let totals = activity.dayTotals(on: day, calendar: calendar)
        return metric(on: day) == .practiced ? totals.practiced : totals.learned
    }

    /// Erreichungs-Status eines Tages relativ zu `today`.
    func status(on day: Date, asOf today: Date = .now) -> DayStatus {
        let d = calendar.startOfDay(for: day)
        let start = calendar.startOfDay(for: today)
        if d > start { return .upcoming }
        let target = dailyTarget(on: d)
        guard target > 0 else { return .noGoal }
        let value = value(on: d)
        if value >= target { return .reached }
        return value > 0 ? .partial : .missed
    }

    private func isReached(on day: Date) -> Bool {
        let target = dailyTarget(on: day)
        return target > 0 && value(on: day) >= target
    }

    // MARK: - Ziel-Streak

    /// Tage in Folge mit erreichtem Tagesziel, gezählt ab `today` rückwärts. Der heutige
    /// Tag darf noch „offen" sein: ist er (noch) nicht erreicht, beginnt die Zählung bei
    /// gestern – analog zum Lern-Streak.
    func goalStreak(asOf today: Date = .now) -> Int {
        var day = calendar.startOfDay(for: today)
        if !isReached(on: day) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = yesterday
        }
        var streak = 0
        while isReached(on: day) {
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return streak
    }

    /// Längste je erreichte Tages-Ziel-Serie im aufgezeichneten Fenster.
    func bestGoalStreak(asOf today: Date = .now) -> Int {
        let end = calendar.startOfDay(for: today)
        // Frühester relevanter Tag: der älteste mit Aktivität oder Ziel-Snapshot.
        let earliest = (activity.days.map(\.day) + history.days.map(\.day)).min()
        guard let start = earliest.map({ calendar.startOfDay(for: $0) }) else { return 0 }
        var best = 0
        var run = 0
        var day = start
        while day <= end {
            if isReached(on: day) {
                run += 1
                best = max(best, run)
            } else {
                run = 0
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return best
    }

    // MARK: - Erfüllungsquote

    /// Anteil der Tage mit gesetztem Tagesziel im Monat von `date`, an denen es erreicht
    /// wurde (`0…1`). `nil`, wenn es im betrachteten Zeitraum keinen Tag mit Ziel gab.
    /// Zukünftige Tage bleiben unberücksichtigt; der heutige Tag zählt erst mit, sobald
    /// sein Ziel erreicht ist (solange „offen" weder Treffer noch Fehlschlag).
    func completionRate(inMonthOf date: Date, asOf today: Date = .now) -> Double? {
        guard let interval = calendar.dateInterval(of: .month, for: date) else { return nil }
        let end = calendar.startOfDay(for: today)
        var withGoal = 0
        var reached = 0
        var day = calendar.startOfDay(for: interval.start)
        while day < interval.end {
            if day > end { break }
            if dailyTarget(on: day) > 0 {
                let reachedDay = isReached(on: day)
                // Der heutige Tag darf noch „offen" sein (analog zum Ziel-Streak): ein
                // noch nicht erreichtes Ziel zählt heute weder als Treffer noch als
                // Fehlschlag – sonst bräche die Monatsquote jeden Morgen ein.
                if day != end || reachedDay {
                    withGoal += 1
                    if reachedDay { reached += 1 }
                }
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return withGoal == 0 ? nil : Double(reached) / Double(withGoal)
    }

    // MARK: - Wochenziel

    /// An der Woche ab `weekStart` geltendes Wochenziel (jüngster Snapshot der Woche,
    /// sonst aktueller Wert).
    func weeklyTarget(forWeekStarting weekStart: Date) -> Int {
        history.latestEntry(inWeekStarting: weekStart, calendar: calendar)?.weeklyTarget ?? currentWeeklyTarget
    }

    /// An der Woche ab `weekStart` geltende Metrik.
    func metric(forWeekStarting weekStart: Date) -> GoalMetric {
        guard let raw = history.latestEntry(inWeekStarting: weekStart, calendar: calendar)?.metricRaw,
              let metric = GoalMetric(rawValue: raw) else { return currentMetric }
        return metric
    }

    /// Wurde das Wochenziel der Kalenderwoche ab `weekStart` erreicht? `false`, wenn kein
    /// Wochenziel galt. Nutzt dieselbe Wochen-Aggregation wie Home/Wochenziel.
    func weekReached(weekStarting weekStart: Date) -> Bool {
        let target = weeklyTarget(forWeekStarting: weekStart)
        guard target > 0 else { return false }
        let totals = activity.currentWeekTotals(asOf: weekStart, calendar: calendar)
        let value = metric(forWeekStarting: weekStart) == .practiced ? totals.practiced : totals.learned
        return value >= target
    }

    /// Anzahl der Kalenderwochen (der letzten `weeks`, aktuelle inklusive), in denen das
    /// jeweilige Wochenziel erreicht wurde.
    func weeklyGoalsReachedCount(weeks: Int, asOf today: Date = .now) -> Int {
        guard weeks > 0 else { return 0 }
        let currentWeekStart = calendar.startOfWeek(for: today)
        return (0 ..< weeks).reduce(into: 0) { count, offset in
            guard let start = calendar.date(byAdding: .day, value: -7 * offset, to: currentWeekStart) else { return }
            if weekReached(weekStarting: start) { count += 1 }
        }
    }
}

extension GoalStats {
    /// Baut die Ziel-Statistik aus den persistierten Stores und den aktuell
    /// eingestellten Zielwerten – die Bezugsquelle für den Statistik-Screen.
    static func current(calendar: Calendar = .current) -> GoalStats {
        let d = AppGroup.defaults
        let metric = GoalMetric(rawValue: d.string(forKey: GoalKeys.metric) ?? "") ?? .practiced
        return GoalStats(
            activity: WeeklyReviewStore.loadActivity(),
            history: GoalHistoryStore.history(),
            currentDailyTarget: d.integer(forKey: GoalKeys.daily),
            currentWeeklyTarget: d.integer(forKey: GoalKeys.weekly),
            currentMetric: metric,
            calendar: calendar
        )
    }
}

/// Persistiert die Ziel-Historie im geteilten App-Group-`UserDefaults` (JSON), analog zu
/// [[WeeklyReviewStore]]. Kein SwiftData nötig – die Snapshots leben, wie Streak/Aktivität,
/// in den Defaults.
enum GoalHistoryStore {
    private static var d: UserDefaults { AppGroup.defaults }

    /// Schreibt den heute geltenden Ziel-Snapshot aus den aktuellen `GoalKeys`-Werten.
    /// Beim App-Start/Home-Erscheinen sowie nach jeder Ziel-Änderung aufrufen. Schreibt
    /// nur, wenn sich der Tageseintrag tatsächlich ändert.
    static func snapshotToday(on date: Date = .now, calendar: Calendar = .current) {
        let metric = GoalMetric(rawValue: d.string(forKey: GoalKeys.metric) ?? "") ?? .practiced
        let daily = d.integer(forKey: GoalKeys.daily)
        let weekly = d.integer(forKey: GoalKeys.weekly)
        let current = load()
        let updated = current.recordingSnapshot(dailyTarget: daily, weeklyTarget: weekly,
                                                metric: metric, on: date, calendar: calendar)
        if updated != current { save(updated) }
    }

    /// Lädt die aufgezeichnete Ziel-Historie (leer, falls noch keine existiert).
    static func history() -> GoalHistory { load() }

    // MARK: - Laden / Speichern

    private static func load() -> GoalHistory {
        guard let data = d.data(forKey: GoalHistoryKeys.log),
              let decoded = try? JSONDecoder().decode(GoalHistory.self, from: data)
        else { return GoalHistory() }
        return decoded
    }

    private static func save(_ history: GoalHistory) {
        guard let data = try? JSONEncoder().encode(history) else { return }
        d.set(data, forKey: GoalHistoryKeys.log)
    }
}
