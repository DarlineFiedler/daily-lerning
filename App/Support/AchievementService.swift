import Foundation
import SwiftData

/// Verbindet die reine Achievement-Logik mit den lebenden Daten (Vokabel-Zähler,
/// Streak) und der Persistenz. Wird nach relevanten Aktionen aufgerufen und gibt
/// die *neu* freigeschalteten Badges zurück (für das Freischalt-Feedback).
@MainActor
enum AchievementService {
    /// Baut die aktuellen Metriken aus dem Store + den Vokabeldaten.
    static func metrics(context: ModelContext, progress: AchievementProgress = AchievementStore.progress) -> AchievementMetrics {
        let learnedRaw = LearningStatus.learned.rawValue
        let learned = (try? context.fetchCount(FetchDescriptor<Vocab>(predicate: #Predicate { $0.statusRaw == learnedRaw }))) ?? 0
        let total = (try? context.fetchCount(FetchDescriptor<Vocab>())) ?? 0
        return AchievementMetrics.from(progress: progress,
                                       learnedWords: learned,
                                       totalWords: total,
                                       longestStreak: StreakStore.longest)
    }

    /// Wertet den aktuellen Stand aus und schaltet neue Badges frei (persistiert).
    /// - Returns: die diesmal neu freigeschalteten Badges (leer = nichts Neues).
    @discardableResult
    static func evaluate(context: ModelContext, on date: Date = .now) -> [Achievement] {
        let unlocked = AchievementEvaluator.newlyUnlocked(metrics: metrics(context: context),
                                                          alreadyUnlocked: AchievementStore.unlockedIDs)
        AchievementStore.markUnlocked(unlocked, on: date)
        return unlocked
    }

    /// Verbucht eine beendete Übungsrunde und wertet danach aus.
    /// - Returns: die neu freigeschalteten Badges.
    @discardableResult
    static func registerSession(modes: Set<PracticeMode>,
                                weekday: Int,
                                hour: Int,
                                isPerfect: Bool,
                                context: ModelContext,
                                on date: Date = .now) -> [Achievement] {
        var progress = AchievementStore.progress
        progress.recordSession(modes: modes, weekday: weekday, hour: hour, isPerfect: isPerfect)
        AchievementStore.progress = progress

        let unlocked = AchievementEvaluator.newlyUnlocked(metrics: metrics(context: context, progress: progress),
                                                          alreadyUnlocked: AchievementStore.unlockedIDs)
        AchievementStore.markUnlocked(unlocked, on: date)
        return unlocked
    }
}
