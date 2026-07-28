import Foundation

enum DailyChallengeKeys {
    static let state = "dailyChallenge.state"
}

/// Reiner, testbarer Zustand der Tages-Challenges: der eigene Mini-Streak
/// („X Tage in Folge erfüllt") und der Gesamtzähler (für die Meta-Badges).
/// Persistenz übernimmt `DailyChallengeStore` – hier steckt nur die Wertlogik.
struct DailyChallengeState: Codable, Equatable {
    var lastCompletedDay: Date?
    var run = 0
    var best = 0
    var totalCompleted = 0

    /// Verbucht eine heute erfüllte Challenge. Idempotent pro Kalendertag (mehrfaches
    /// Erfüllen am selben Tag zählt einmal). Ein Folgetag erhöht den Streak, eine Lücke
    /// > 1 Tag setzt ihn folgenlos auf 1 zurück (keine Schonfrist wie beim Haupt-Streak).
    func recordingCompletion(on date: Date, calendar: Calendar = .current) -> DailyChallengeState {
        let day = calendar.startOfDay(for: date)
        if let last = lastCompletedDay, calendar.isDate(last, inSameDayAs: day) {
            return self // heute schon gezählt
        }
        var copy = self
        let gap = lastCompletedDay.map { calendar.dateComponents([.day], from: calendar.startOfDay(for: $0), to: day).day ?? 0 }
        copy.run = gap == 1 ? run + 1 : 1
        copy.lastCompletedDay = day
        copy.best = Swift.max(best, copy.run)
        copy.totalCompleted = totalCompleted + 1
        return copy
    }

    /// Angezeigter Mini-Streak: nur gültig, wenn zuletzt heute oder gestern erfüllt –
    /// sonst 0 (Muster wie `StreakStore.displayStreak`).
    func displayStreak(asOf date: Date = .now, calendar: Calendar = .current) -> Int {
        guard let last = lastCompletedDay else { return 0 }
        let today = calendar.startOfDay(for: date)
        let gap = calendar.dateComponents([.day], from: calendar.startOfDay(for: last), to: today).day ?? 0
        return (gap == 0 || gap == 1) ? run : 0
    }
}

/// Persistiert die Tages-Challenge-Auswertung in den geteilten App-Group-Defaults
/// (JSON, analog zu `WeeklyReviewStore`). Die Challenge-Auswahl selbst ist zustandslos
/// (`DailyChallengeCatalog.forDay`); hier liegt nur der erfüllte Mini-Streak/Zähler.
enum DailyChallengeStore {
    private static var d: UserDefaults { AppGroup.defaults }

    /// Heutige Challenge – deterministisch pro Kalendertag.
    static func today(now: Date = .now, calendar: Calendar = .current) -> DailyChallenge {
        DailyChallengeCatalog.forDay(index: DailyChallengeCalendar.todayIndex(now: now, calendar: calendar))
    }

    /// Fortschritt der heutigen Challenge, abgeleitet aus dem Achievement-Tagespuffer.
    static func snapshot(progress: AchievementProgress = AchievementStore.progress,
                         now: Date = .now,
                         calendar: Calendar = .current) -> DailyChallengeSnapshot {
        let challenge = today(now: now, calendar: calendar)
        return DailyChallengeSnapshot(challenge: challenge,
                                      done: challenge.done(from: progress, now: now, calendar: calendar))
    }

    /// Verbucht die Erfüllung der heutigen Challenge, falls erreicht und noch nicht
    /// für heute gezählt. Wird nach einer Übungsrunde aufgerufen.
    static func registerCompletionIfNeeded(progress: AchievementProgress,
                                           on date: Date = .now,
                                           calendar: Calendar = .current) {
        let challenge = today(now: date, calendar: calendar)
        guard challenge.isSatisfied(from: progress, now: date, calendar: calendar) else { return }
        let updated = load().recordingCompletion(on: date, calendar: calendar)
        save(updated)
    }

    /// Angezeigter Mini-Streak („X Tage in Folge erfüllt").
    static func displayStreak(asOf date: Date = .now, calendar: Calendar = .current) -> Int {
        load().displayStreak(asOf: date, calendar: calendar)
    }

    /// Gesamtzahl erfüllter Tages-Challenges (für die Meta-Badges).
    static var totalCompleted: Int { load().totalCompleted }

    /// Längster je erreichter Mini-Streak.
    static var best: Int { load().best }

    // MARK: - Persistenz

    private static func load() -> DailyChallengeState {
        guard let data = d.data(forKey: DailyChallengeKeys.state),
              let decoded = try? JSONDecoder().decode(DailyChallengeState.self, from: data)
        else { return DailyChallengeState() }
        return decoded
    }

    private static func save(_ state: DailyChallengeState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        d.set(data, forKey: DailyChallengeKeys.state)
    }
}
