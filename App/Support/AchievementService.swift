import Foundation
import SwiftData

/// Verbindet die reine Achievement-Logik mit den lebenden Daten (Vokabel-Zähler,
/// Streak) und der Persistenz. Wird nach relevanten Aktionen aufgerufen und gibt
/// die *neu* freigeschalteten Badges zurück (für das Freischalt-Feedback).
@MainActor
enum AchievementService {
    /// Mindestgröße einer Gruppe, damit ihr vollständiges Lernen als „Themen-Meister"
    /// zählt – verhindert, dass eine winzige Gruppe das Badge trivial freischaltet.
    static let themenMeisterMinSize = 5

    /// Baut die aktuellen Metriken aus dem Store + den Vokabeldaten.
    static func metrics(context: ModelContext, progress: AchievementProgress = AchievementStore.progress) -> AchievementMetrics {
        let learnedRaw = LearningStatus.learned.rawValue
        let learned = (try? context.fetchCount(FetchDescriptor<Vocab>(predicate: #Predicate { $0.statusRaw == learnedRaw }))) ?? 0
        let total = (try? context.fetchCount(FetchDescriptor<Vocab>())) ?? 0
        return AchievementMetrics.from(progress: progress,
                                       learnedWords: learned,
                                       totalWords: total,
                                       longestStreak: StreakStore.longest,
                                       groupMastered: hasMasteredGroup(context: context),
                                       allGroupsMastered: hasMasteredAllGroups(context: context),
                                       everUsedJoker: !StreakStore.jokerUses.isEmpty,
                                       unlockedIDs: AchievementStore.unlockedIDs)
    }

    /// Ist mindestens eine ausreichend große Vokabelgruppe komplett gelernt?
    private static func hasMasteredGroup(context: ModelContext) -> Bool {
        let learnedRaw = LearningStatus.learned.rawValue
        let groups = (try? context.fetch(FetchDescriptor<VocabGroup>())) ?? []
        return groups.contains { group in
            group.vocabs.count >= themenMeisterMinSize
                && group.vocabs.allSatisfy { $0.statusRaw == learnedRaw }
        }
    }

    /// Sind *alle* nicht-leeren Vokabelgruppen komplett gelernt (härtere Version von
    /// „Themen-Meister")? Verlangt insgesamt genug Wörter, damit es nicht trivial ist.
    private static func hasMasteredAllGroups(context: ModelContext) -> Bool {
        let learnedRaw = LearningStatus.learned.rawValue
        let groups = (try? context.fetch(FetchDescriptor<VocabGroup>())) ?? []
        let nonEmpty = groups.filter { !$0.vocabs.isEmpty }
        let totalVocabs = nonEmpty.reduce(0) { $0 + $1.vocabs.count }
        guard !nonEmpty.isEmpty, totalVocabs >= themenMeisterMinSize else { return false }
        return nonEmpty.allSatisfy { group in
            group.vocabs.allSatisfy { $0.statusRaw == learnedRaw }
        }
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
                                date: Date = .now,
                                isPerfect: Bool,
                                isFlawless: Bool = false,
                                selfCorrected: Bool = false,
                                newlyLearned: Int = 0,
                                currentStreak: Int = 0,
                                groups: Set<String> = [],
                                context: ModelContext) -> [Achievement] {
        var progress = AchievementStore.progress
        progress.recordSession(modes: modes,
                               date: date,
                               isPerfect: isPerfect,
                               isFlawless: isFlawless,
                               selfCorrected: selfCorrected,
                               newlyLearned: newlyLearned,
                               currentStreak: currentStreak,
                               groups: groups)
        AchievementStore.progress = progress

        let unlocked = AchievementEvaluator.newlyUnlocked(metrics: metrics(context: context, progress: progress),
                                                          alreadyUnlocked: AchievementStore.unlockedIDs)
        AchievementStore.markUnlocked(unlocked, on: date)
        return unlocked
    }

    /// Setzt ein einfaches Ereignis-Flag im Fortschritt (z.B. „Suche benutzt") und
    /// wertet sofort aus. Idempotent: ist das Flag schon gesetzt, passiert nichts.
    /// - Returns: die dadurch neu freigeschalteten Badges (für ein evtl. Feedback).
    @discardableResult
    static func recordEvent(_ keyPath: WritableKeyPath<AchievementProgress, Bool>,
                            date: Date = .now,
                            context: ModelContext) -> [Achievement] {
        var progress = AchievementStore.progress
        guard !progress[keyPath: keyPath] else { return [] }
        progress[keyPath: keyPath] = true
        AchievementStore.progress = progress

        let unlocked = AchievementEvaluator.newlyUnlocked(metrics: metrics(context: context, progress: progress),
                                                          alreadyUnlocked: AchievementStore.unlockedIDs)
        AchievementStore.markUnlocked(unlocked, on: date)
        return unlocked
    }
}
