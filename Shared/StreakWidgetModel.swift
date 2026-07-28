import Foundation

/// Anzeige-Modell für das Streak-Home-Screen-Widget: der sichtbare Tages-Streak
/// plus – falls ein persönliches Ziel gesetzt ist – der Fortschritt gegen das
/// Tages- bzw. Wochenziel (für den Fortschrittsring).
///
/// Bewusst in `Shared/` (nicht im Widget-Target), damit die reine Auswahllogik
/// (`make`) unabhängig von WidgetKit unit-testbar bleibt – analog zu
/// [[WidgetSnapshot]]. Liest über [[StreakStore]] / [[WeeklyReviewStore]] denselben
/// App-Group-Zustand wie der Home-Screen der App.
struct StreakWidgetModel: Equatable {
    let streak: Int
    let longest: Int
    /// Fortschritt gegen das aktive Ziel; `nil`, wenn gar kein Ziel gesetzt ist
    /// (dann zeigt das Widget nur den Streak – reiner Fallback).
    let goal: GoalProgress?

    /// Fortschritt gegen genau eine Ziel-Ebene (Tag oder Woche).
    struct GoalProgress: Equatable {
        let done: Int
        let target: Int
        /// `true` = Tagesziel, `false` = Wochenziel (steuert das Ring-Label).
        let isDaily: Bool

        /// Gefüllter Ring-Anteil, geklemmt auf `0...1`.
        var fraction: Double { target > 0 ? min(1, Double(done) / Double(target)) : 0 }
        /// Ziel erreicht? (Ring voll, Erfolgs-Farbe).
        var reached: Bool { target > 0 && done >= target }
    }

    /// Reine Auswahllogik: bevorzugt das **Tagesziel** (wenn gesetzt, `target > 0`),
    /// sonst das **Wochenziel**, sonst kein Ring. Ohne Seiteneffekte → isoliert testbar.
    static func make(streak: Int, longest: Int,
                     daily: (done: Int, target: Int),
                     weekly: (done: Int, target: Int)) -> StreakWidgetModel {
        let goal: GoalProgress?
        if daily.target > 0 {
            goal = GoalProgress(done: daily.done, target: daily.target, isDaily: true)
        } else if weekly.target > 0 {
            goal = GoalProgress(done: weekly.done, target: weekly.target, isDaily: false)
        } else {
            goal = nil
        }
        return StreakWidgetModel(streak: streak, longest: longest, goal: goal)
    }

    /// Liest den aktuellen geteilten Zustand (App-Group-`UserDefaults` + Stores)
    /// für die Widget-Timeline zusammen.
    static func current(asOf date: Date = .now) -> StreakWidgetModel {
        let d = AppGroup.defaults
        let metric = GoalMetric(rawValue: d.string(forKey: GoalKeys.metric) ?? "") ?? .practiced
        return make(
            streak: StreakStore.displayStreak(asOf: date),
            longest: StreakStore.longest,
            daily: (WeeklyReviewStore.dayProgress(for: metric, asOf: date), d.integer(forKey: GoalKeys.daily)),
            weekly: (WeeklyReviewStore.weekProgress(for: metric, asOf: date), d.integer(forKey: GoalKeys.weekly))
        )
    }
}
