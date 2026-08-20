import Foundation
import SwiftData

/// Ergebnis der Gruppen-Meisterschafts-Auswertung (siehe `AchievementService.groupMastery`).
/// `any` = eine ausreichend große Gruppe komplett gelernt, `all` = alle Gruppen gemeistert,
/// `big` = ein „Voller Garten" (große Gruppe komplett gelernt, Issue #92).
struct GroupMastery: Equatable {
    let any: Bool
    let all: Bool
    let big: Bool
}

/// Verbindet die reine Achievement-Logik mit den lebenden Daten (Vokabel-Zähler,
/// Streak) und der Persistenz. Wird nach relevanten Aktionen aufgerufen und gibt
/// die *neu* freigeschalteten Badges zurück (für das Freischalt-Feedback).
@MainActor
enum AchievementService {
    /// Mindestgröße einer Gruppe, damit ihr vollständiges Lernen als „Themen-Meister"
    /// zählt – verhindert, dass eine winzige Gruppe das Badge trivial freischaltet.
    static let themenMeisterMinSize = 5

    /// Mindestgröße für den „Voller Garten"-Prunk (Issue #92): eine komplett gelernte
    /// Gruppe dieser Größe ergibt einen sichtbar üppigen, teilenswerten Garten – bewusst
    /// höher als `themenMeisterMinSize`, damit das Badge etwas Besonderes bleibt.
    static let gardenBloomMinSize = 15

    /// Baut die aktuellen Metriken aus dem Store + den Vokabeldaten.
    static func metrics(context: ModelContext, progress: AchievementProgress = AchievementStore.progress) -> AchievementMetrics {
        let learnedRaw = LearningStatus.learned.rawValue
        let learned = (try? context.fetchCount(FetchDescriptor<Vocab>(predicate: #Predicate { $0.statusRaw == learnedRaw }))) ?? 0
        let total = (try? context.fetchCount(FetchDescriptor<Vocab>())) ?? 0
        // Gruppen einmal fetchen und pro Gruppe in einem Durchlauf die Kennzahlen bilden –
        // beide Meister-Ableitungen (eine Gruppe / alle Gruppen) speisen sich daraus.
        let groups = (try? context.fetch(FetchDescriptor<VocabGroup>())) ?? []
        let summaries = groups.map { group in
            (count: group.vocabs.count,
             learned: group.vocabs.reduce(0) { $0 + ($1.statusRaw == learnedRaw ? 1 : 0) })
        }
        let mastery = groupMastery(from: summaries)
        return AchievementMetrics.from(progress: progress,
                                       learnedWords: learned,
                                       totalWords: total,
                                       longestStreak: StreakStore.longest,
                                       groupMastered: mastery.any,
                                       allGroupsMastered: mastery.all,
                                       bigGardenBloomed: mastery.big,
                                       everUsedJoker: !StreakStore.jokerUses.isEmpty,
                                       dailyChallengesCompleted: DailyChallengeStore.totalCompleted,
                                       unlockedIDs: AchievementStore.unlockedIDs)
    }

    /// Reine Auswertung aus Gruppen-Kennzahlen (Vokabelzahl + davon gelernt), damit ein
    /// einziger Gruppen-Fetch beide Badge-Ableitungen speist – und die Logik testbar bleibt.
    /// - `any`: mindestens eine ausreichend große Gruppe (`>= themenMeisterMinSize`) komplett
    ///   gelernt („Themen-Meister").
    /// - `all`: alle nicht-leeren Gruppen komplett gelernt und insgesamt genug Wörter, damit
    ///   es nicht trivial ist (härtere Version).
    /// - `big`: mindestens eine komplett gelernte Gruppe mit `>= gardenBloomMinSize` Wörtern
    ///   („Voller Garten", Issue #92).
    static func groupMastery(from groups: [(count: Int, learned: Int)]) -> GroupMastery {
        var anyMastered = false
        var bigBloomed = false
        var allNonEmptyMastered = true
        var hasNonEmpty = false
        var totalNonEmptyVocabs = 0
        for group in groups where group.count > 0 {
            hasNonEmpty = true
            totalNonEmptyVocabs += group.count
            let fullyLearned = group.learned == group.count
            if group.count >= themenMeisterMinSize, fullyLearned { anyMastered = true }
            if group.count >= gardenBloomMinSize, fullyLearned { bigBloomed = true }
            if !fullyLearned { allNonEmptyMastered = false }
        }
        let all = hasNonEmpty && totalNonEmptyVocabs >= themenMeisterMinSize && allNonEmptyMastered
        return GroupMastery(any: anyMastered, all: all, big: bigBloomed)
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
                                bossDefeated: Bool = false,
                                maxCombo: Int = 0,
                                context: ModelContext) -> [Achievement] {
        var progress = AchievementStore.progress
        progress.recordSession(modes: modes,
                               date: date,
                               isPerfect: isPerfect,
                               isFlawless: isFlawless,
                               selfCorrected: selfCorrected,
                               newlyLearned: newlyLearned,
                               currentStreak: currentStreak,
                               groups: groups,
                               bossDefeated: bossDefeated,
                               maxCombo: maxCombo)
        AchievementStore.progress = progress
        // Tages-Challenge gegen den frischen Tagespuffer prüfen und ggf. verbuchen –
        // vor der Auswertung, damit das Meta-Badge im selben Aufruf freischalten kann.
        DailyChallengeStore.registerCompletionIfNeeded(progress: progress, on: date)

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
