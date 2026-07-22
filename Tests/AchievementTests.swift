@testable import DailyHangul
import XCTest

/// Prüft die reine Achievement-Logik: Freischalt-Bedingungen, Fortschritt, das
/// Sammeln des Lernverhaltens und die Auswertung neu freigeschalteter Badges.
final class AchievementTests: XCTestCase {

    // MARK: - Einzelbedingung

    func testCountRequirementUnlocksAtThreshold() {
        let a = Achievement(id: "x", category: .learned, emoji: "🌱", requirement: .count(\.learnedWords, 10))
        XCTAssertFalse(a.isUnlocked(AchievementMetrics(learnedWords: 9)))
        XCTAssertTrue(a.isUnlocked(AchievementMetrics(learnedWords: 10)))
        XCTAssertTrue(a.isUnlocked(AchievementMetrics(learnedWords: 42)))
    }

    func testFlagRequirement() {
        let a = Achievement(id: "owl", category: .fun, emoji: "🦉", requirement: .flag(\.nightOwl))
        XCTAssertFalse(a.isUnlocked(AchievementMetrics(nightOwl: false)))
        XCTAssertTrue(a.isUnlocked(AchievementMetrics(nightOwl: true)))
    }

    func testProgressClampsToOne() {
        let a = Achievement(id: "x", category: .learned, emoji: "🌱", requirement: .count(\.learnedWords, 10))
        XCTAssertEqual(a.progress(AchievementMetrics(learnedWords: 0)), 0, accuracy: 0.0001)
        XCTAssertEqual(a.progress(AchievementMetrics(learnedWords: 5)), 0.5, accuracy: 0.0001)
        XCTAssertEqual(a.progress(AchievementMetrics(learnedWords: 20)), 1, accuracy: 0.0001)
    }

    func testProgressTextForCountAndFlag() {
        let count = Achievement(id: "x", category: .learned, emoji: "🌱", requirement: .count(\.learnedWords, 10))
        XCTAssertEqual(count.progressText(AchievementMetrics(learnedWords: 3)), "3 / 10")
        // Über dem Ziel wird bei „x / y" gedeckelt.
        XCTAssertEqual(count.progressText(AchievementMetrics(learnedWords: 99)), "10 / 10")
        let flag = Achievement(id: "owl", category: .fun, emoji: "🦉", requirement: .flag(\.nightOwl))
        XCTAssertNil(flag.progressText(AchievementMetrics(nightOwl: true)))
    }

    // MARK: - Fortschritt sammeln

    func testRecordSessionAccumulates() {
        var p = AchievementProgress()
        p.recordSession(modes: [.review, .writing], weekday: 2, hour: 14, isPerfect: true)
        p.recordSession(modes: [.review, .multipleChoice], weekday: 3, hour: 14, isPerfect: false)
        XCTAssertEqual(p.modesUsed, ["review", "writing", "multipleChoice"])
        XCTAssertEqual(p.weekdays, [2, 3])
        XCTAssertEqual(p.sessionsCompleted, 2)
        XCTAssertEqual(p.perfectRounds, 1)
    }

    func testRecordSessionHourBoundaries() {
        var night = AchievementProgress()
        night.recordSession(modes: [.review], weekday: 1, hour: 2, isPerfect: false)
        XCTAssertTrue(night.nightOwl)
        XCTAssertFalse(night.earlyBird)

        var early = AchievementProgress()
        early.recordSession(modes: [.review], weekday: 1, hour: 6, isPerfect: false)
        XCTAssertTrue(early.earlyBird)
        XCTAssertFalse(early.nightOwl)

        var day = AchievementProgress()
        day.recordSession(modes: [.review], weekday: 1, hour: 12, isPerfect: false)
        XCTAssertFalse(day.nightOwl)
        XCTAssertFalse(day.earlyBird)
    }

    func testMetricsFromProgress() {
        var p = AchievementProgress()
        p.recordSession(modes: [.review, .writing, .listening], weekday: 5, hour: 20, isPerfect: false)
        let m = AchievementMetrics.from(progress: p, learnedWords: 42, totalWords: 100, longestStreak: 7)
        XCTAssertEqual(m.learnedWords, 42)
        XCTAssertEqual(m.totalWords, 100)
        XCTAssertEqual(m.longestStreak, 7)
        XCTAssertEqual(m.distinctModes, 3)
        XCTAssertEqual(m.distinctWeekdays, 1)
        XCTAssertEqual(m.sessionsCompleted, 1)
    }

    // MARK: - Auswertung

    func testEvaluatorReturnsOnlyNewlyUnlocked() {
        let metrics = AchievementMetrics(learnedWords: 100, longestStreak: 3)
        // Ohne Vorwissen: alle bis 100 Wörter + Streak-3 sind neu.
        let first = AchievementEvaluator.newlyUnlocked(metrics: metrics, alreadyUnlocked: [])
        let ids = Set(first.map(\.id))
        XCTAssertTrue(ids.isSuperset(of: ["learned1", "learned10", "learned50", "learned100", "streak3"]))
        XCTAssertFalse(ids.contains("learned250"))
        XCTAssertFalse(ids.contains("streak7"))

        // Sind sie bereits bekannt, kommt nichts Neues zurück.
        let again = AchievementEvaluator.newlyUnlocked(metrics: metrics, alreadyUnlocked: ids)
        XCTAssertTrue(again.isEmpty)
    }

    func testEvaluatorFunAndVarietyBadges() {
        let metrics = AchievementMetrics(distinctModes: 4, distinctWeekdays: 7,
                                         perfectRounds: 1, nightOwl: true, earlyBird: true)
        let ids = Set(AchievementEvaluator.newlyUnlocked(metrics: metrics, alreadyUnlocked: []).map(\.id))
        XCTAssertTrue(ids.isSuperset(of: ["modes3", "modesAll", "weekday5", "weekday7",
                                          "perfect", "nightOwl", "earlyBird"]))
    }

    // MARK: - Katalog-Integrität

    func testCatalogIDsAreUnique() {
        let ids = AchievementCatalog.all.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count, "Achievement-IDs müssen eindeutig sein")
    }

    func testCatalogHasEmojiForEach() {
        for a in AchievementCatalog.all {
            XCTAssertFalse(a.emoji.isEmpty, "\(a.id) braucht ein Emoji")
        }
    }

    func testEmptyMetricsUnlockNothing() {
        XCTAssertTrue(AchievementEvaluator.newlyUnlocked(metrics: AchievementMetrics(), alreadyUnlocked: []).isEmpty)
    }
}
