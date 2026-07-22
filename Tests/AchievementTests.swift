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

    // MARK: - Hilfen (deterministischer Kalender/Datumsbau)

    /// Fester Kalender (Gregorianisch, UTC) – damit Wochentag/Stunde reproduzierbar sind.
    private static let utc: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    private func date(_ y: Int, _ mo: Int, _ d: Int, _ h: Int = 12, _ mi: Int = 0) -> Date {
        var c = DateComponents()
        c.year = y; c.month = mo; c.day = d; c.hour = h; c.minute = mi
        return Self.utc.date(from: c)!
    }

    // MARK: - Fortschritt sammeln

    func testRecordSessionAccumulates() {
        let cal = Self.utc
        var p = AchievementProgress()
        // 2024-01-15 = Montag (Wochentag 2), 2024-01-16 = Dienstag (3).
        p.recordSession(modes: [.review, .writing], date: date(2024, 1, 15, 14), isPerfect: true, calendar: cal)
        p.recordSession(modes: [.review, .multipleChoice], date: date(2024, 1, 16, 14), isPerfect: false, calendar: cal)
        XCTAssertEqual(p.modesUsed, ["review", "writing", "multipleChoice"])
        XCTAssertEqual(p.weekdays, [2, 3])
        XCTAssertEqual(p.sessionsCompleted, 2)
        XCTAssertEqual(p.perfectRounds, 1)
    }

    func testRecordSessionHourBoundaries() {
        let cal = Self.utc
        var night = AchievementProgress()
        night.recordSession(modes: [.review], date: date(2024, 1, 15, 2), isPerfect: false, calendar: cal)
        XCTAssertTrue(night.nightOwl)
        XCTAssertFalse(night.earlyBird)

        var early = AchievementProgress()
        early.recordSession(modes: [.review], date: date(2024, 1, 15, 6), isPerfect: false, calendar: cal)
        XCTAssertTrue(early.earlyBird)
        XCTAssertFalse(early.nightOwl)

        var day = AchievementProgress()
        day.recordSession(modes: [.review], date: date(2024, 1, 15, 12), isPerfect: false, calendar: cal)
        XCTAssertFalse(day.nightOwl)
        XCTAssertFalse(day.earlyBird)
    }

    func testMetricsFromProgress() {
        let cal = Self.utc
        var p = AchievementProgress()
        p.recordSession(modes: [.review, .writing, .listening], date: date(2024, 5, 17, 19), isPerfect: false, calendar: cal)
        let m = AchievementMetrics.from(progress: p, learnedWords: 42, totalWords: 100, longestStreak: 7)
        XCTAssertEqual(m.learnedWords, 42)
        XCTAssertEqual(m.totalWords, 100)
        XCTAssertEqual(m.longestStreak, 7)
        XCTAssertEqual(m.distinctModes, 3)
        XCTAssertEqual(m.distinctWeekdays, 1)
        XCTAssertEqual(m.sessionsCompleted, 1)
        XCTAssertTrue(m.usedListening) // listening war dabei
        XCTAssertTrue(m.afterWork) // 20 Uhr → Feierabend
    }

    // MARK: - Neue Badges: Kalender-/Verhaltens-Flags

    func testAfterWorkWeekendAndListeningFlags() {
        let cal = Self.utc
        var p = AchievementProgress()
        // 2024-09-14 = Samstag (Wochentag 7), 19 Uhr → Feierabend + Wochenende.
        p.recordSession(modes: [.listening], date: date(2024, 9, 14, 19), isPerfect: false, calendar: cal)
        XCTAssertTrue(p.afterWork)
        XCTAssertTrue(p.weekend)
        let m = AchievementMetrics.from(progress: p, learnedWords: 0, totalWords: 0, longestStreak: 0)
        XCTAssertTrue(m.usedListening)
        XCTAssertTrue(m.weekend)
    }

    func testGhostHourFridayThe13thAndNewYearsEve() {
        let cal = Self.utc
        var ghost = AchievementProgress()
        ghost.recordSession(modes: [.review], date: date(2024, 6, 1, 0, 0), isPerfect: false, calendar: cal)
        XCTAssertTrue(ghost.ghostHour)

        var notGhost = AchievementProgress()
        notGhost.recordSession(modes: [.review], date: date(2024, 6, 1, 0, 5), isPerfect: false, calendar: cal)
        XCTAssertFalse(notGhost.ghostHour)

        var fri13 = AchievementProgress()
        fri13.recordSession(modes: [.review], date: date(2024, 9, 13, 10), isPerfect: false, calendar: cal) // Fr, 13.
        XCTAssertTrue(fri13.fridayThe13th)

        var nye = AchievementProgress()
        nye.recordSession(modes: [.review], date: date(2024, 12, 31, 22), isPerfect: false, calendar: cal)
        XCTAssertTrue(nye.newYearsEve)
    }

    func testComebackAfterBreak() {
        let cal = Self.utc
        var p = AchievementProgress()
        p.recordSession(modes: [.review], date: date(2024, 3, 1, 12), isPerfect: false, calendar: cal)
        XCTAssertFalse(p.comeback)
        // 3 Tage später (Lücke ≥ 3) → Comeback.
        p.recordSession(modes: [.review], date: date(2024, 3, 4, 12), isPerfect: false, calendar: cal)
        XCTAssertTrue(p.comeback)
    }

    func testFourSeasons() {
        let cal = Self.utc
        var p = AchievementProgress()
        for month in [1, 4, 7, 10] {
            p.recordSession(modes: [.review], date: date(2024, month, 10, 12), isPerfect: false, calendar: cal)
        }
        XCTAssertEqual(p.seasons.count, 4)
    }

    // MARK: - Neue Badges: Serien

    func testDoublePackAndAllModesOneDay() {
        let cal = Self.utc
        var p = AchievementProgress()
        p.recordSession(modes: [.review], date: date(2024, 2, 1, 9), isPerfect: false, calendar: cal)
        XCTAssertFalse(p.doublePack)
        p.recordSession(modes: [.writing], date: date(2024, 2, 1, 18), isPerfect: false, calendar: cal)
        XCTAssertTrue(p.doublePack) // 2× am selben Tag

        var all = AchievementProgress()
        all.recordSession(modes: [.review, .writing, .multipleChoice, .listening],
                          date: date(2024, 2, 2, 9), isPerfect: false, calendar: cal)
        XCTAssertTrue(all.allModesOneDay)
    }

    func testFlawlessRoundStreak() {
        let cal = Self.utc
        var p = AchievementProgress()
        p.recordSession(modes: [.review], date: date(2024, 2, 1, 9), isPerfect: false, isFlawless: true, calendar: cal)
        p.recordSession(modes: [.review], date: date(2024, 2, 1, 10), isPerfect: false, isFlawless: true, calendar: cal)
        p.recordSession(modes: [.review], date: date(2024, 2, 1, 11), isPerfect: false, isFlawless: false, calendar: cal)
        p.recordSession(modes: [.review], date: date(2024, 2, 1, 12), isPerfect: false, isFlawless: true, calendar: cal)
        XCTAssertEqual(p.flawlessRun.best, 2) // längste fehlerfreie Serie
        XCTAssertEqual(p.flawlessRun.run, 1) // aktuelle nach dem Fehler
    }

    func testSameModeDayStreak() {
        let cal = Self.utc
        var p = AchievementProgress()
        for day in 1 ... 5 {
            p.recordSession(modes: [.review], date: date(2024, 4, day, 12), isPerfect: false, calendar: cal)
        }
        XCTAssertEqual(p.sameMode.best, 5)
        // Anderer Modus am Folgetag setzt die Serie zurück.
        p.recordSession(modes: [.writing], date: date(2024, 4, 6, 12), isPerfect: false, calendar: cal)
        XCTAssertEqual(p.sameMode.run, 1)
        XCTAssertEqual(p.sameMode.best, 5)
    }

    func testNightStreakBreaksOnGap() {
        let cal = Self.utc
        var p = AchievementProgress()
        p.recordSession(modes: [.review], date: date(2024, 4, 1, 2), isPerfect: false, calendar: cal)
        p.recordSession(modes: [.review], date: date(2024, 4, 2, 3), isPerfect: false, calendar: cal)
        p.recordSession(modes: [.review], date: date(2024, 4, 3, 1), isPerfect: false, calendar: cal)
        XCTAssertEqual(p.nightNights.best, 3)
        // Tageslicht-Session unterbricht nicht (zählt nur nicht) …
        p.recordSession(modes: [.review], date: date(2024, 4, 4, 14), isPerfect: false, calendar: cal)
        // … aber eine echte Nacht-Lücke setzt zurück.
        p.recordSession(modes: [.review], date: date(2024, 4, 6, 2), isPerfect: false, calendar: cal)
        XCTAssertEqual(p.nightNights.run, 1)
        XCTAssertEqual(p.nightNights.best, 3)
    }

    func testOneWordDayStreakAndRollback() {
        let cal = Self.utc
        var p = AchievementProgress()
        // 3 Tage je genau 1 neues Wort.
        for day in 1 ... 3 {
            p.recordSession(modes: [.review], date: date(2024, 5, day, 12), isPerfect: false, newlyLearned: 1, calendar: cal)
        }
        XCTAssertEqual(p.oneWordDays.run, 3)
        // Am selben (3.) Tag ein zweites Wort → Tag disqualifiziert, run rollt zurück auf 2.
        p.recordSession(modes: [.review], date: date(2024, 5, 3, 18), isPerfect: false, newlyLearned: 1, calendar: cal)
        XCTAssertEqual(p.oneWordDays.run, 2)
        XCTAssertEqual(p.oneWordDays.best, 3) // best bleibt bewusst stehen
    }

    func testSerienComeback() {
        let cal = Self.utc
        var p = AchievementProgress()
        // Streak baut sich auf …
        p.recordSession(modes: [.review], date: date(2024, 6, 1, 12), isPerfect: false, currentStreak: 3, calendar: cal)
        p.recordSession(modes: [.review], date: date(2024, 6, 2, 12), isPerfect: false, currentStreak: 4, calendar: cal)
        // … reißt (currentStreak fällt) …
        p.recordSession(modes: [.review], date: date(2024, 6, 10, 12), isPerfect: false, currentStreak: 1, calendar: cal)
        XCTAssertFalse(p.serienComeback)
        // … und übertrifft danach den alten Wert.
        p.recordSession(modes: [.review], date: date(2024, 6, 11, 12), isPerfect: false, currentStreak: 5, calendar: cal)
        XCTAssertTrue(p.serienComeback)
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

    // MARK: - Persistenz (AchievementStore)

    /// Sichert und leert die Achievement-Keys vor jedem Store-Test und stellt sie
    /// danach exakt wieder her, damit der geteilte App-Group-Container nicht leakt.
    private static let storeKeys = [
        AchievementKeys.unlockedIDs, AchievementKeys.unlockDates, AchievementKeys.progress,
        AchievementKeys.modesUsed, AchievementKeys.weekdays, AchievementKeys.sessions,
        AchievementKeys.perfectRounds, AchievementKeys.nightOwl, AchievementKeys.earlyBird,
    ]
    private var savedDefaults: [String: Any?] = [:]

    private func withCleanStore(_ body: () -> Void) {
        let d = AppGroup.defaults
        for key in Self.storeKeys {
            savedDefaults[key] = d.object(forKey: key)
            d.removeObject(forKey: key)
        }
        defer {
            for key in Self.storeKeys {
                if let value = savedDefaults[key], let value { d.set(value, forKey: key) }
                else { d.removeObject(forKey: key) }
            }
            savedDefaults = [:]
        }
        body()
    }

    func testProgressRoundTripsThroughDefaults() {
        withCleanStore {
            let cal = Self.utc
            var p = AchievementProgress()
            p.recordSession(modes: [.review, .writing], date: date(2024, 1, 10, 2), isPerfect: true,
                            isFlawless: true, newlyLearned: 1, currentStreak: 1, calendar: cal)
            p.recordSession(modes: [.listening], date: date(2024, 1, 13, 6), isPerfect: false, calendar: cal)
            AchievementStore.progress = p
            // Frisch aus den Defaults (JSON) gelesen muss identisch sein – inkl. Serien-Zustand.
            XCTAssertEqual(AchievementStore.progress, p)
        }
    }

    func testLegacyProgressMigratesFromScalarKeys() {
        withCleanStore {
            let d = AppGroup.defaults
            // Alte Installation: nur die Skalar-Keys, kein JSON.
            d.set(["review", "listening"], forKey: AchievementKeys.modesUsed)
            d.set([2, 3], forKey: AchievementKeys.weekdays)
            d.set(7, forKey: AchievementKeys.sessions)
            d.set(2, forKey: AchievementKeys.perfectRounds)
            d.set(true, forKey: AchievementKeys.nightOwl)
            let migrated = AchievementStore.progress
            XCTAssertEqual(migrated.modesUsed, ["review", "listening"])
            XCTAssertEqual(migrated.sessionsCompleted, 7)
            XCTAssertEqual(migrated.perfectRounds, 2)
            XCTAssertTrue(migrated.nightOwl)
        }
    }

    func testMarkUnlockedIsIdempotentAndKeepsFirstDate() {
        withCleanStore {
            let badge = AchievementCatalog.all[0]
            let first = Date(timeIntervalSince1970: 1_000_000)
            let later = Date(timeIntervalSince1970: 2_000_000)
            AchievementStore.markUnlocked([badge], on: first)
            AchievementStore.markUnlocked([badge], on: later) // erneut → darf Datum nicht überschreiben
            XCTAssertEqual(AchievementStore.unlockedIDs, [badge.id])
            XCTAssertEqual(AchievementStore.unlockDate(for: badge.id), first)
        }
    }
}
