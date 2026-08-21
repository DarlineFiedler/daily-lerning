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
        // Alle Modi an einem Tag schaltet das Badge frei.
        all.recordSession(modes: [.review, .writing, .multipleChoice, .listening, .cloze],
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

    // MARK: - Neue Badges: Kalender, Comeback-König, Sprachmix, Meta

    func testHangulDayFlag() {
        let cal = Self.utc
        var p = AchievementProgress()
        p.recordSession(modes: [.review], date: date(2025, 10, 9, 12), isPerfect: false, calendar: cal)
        XCTAssertTrue(p.hangulDay)
        var other = AchievementProgress()
        other.recordSession(modes: [.review], date: date(2025, 10, 10, 12), isPerfect: false, calendar: cal)
        XCTAssertFalse(other.hangulDay)
    }

    func testFullMoonFlag() {
        let cal = Self.utc
        var p = AchievementProgress()
        // 2026-01-03 ist ein Vollmond-Datum in der festen Liste.
        p.recordSession(modes: [.review], date: date(2026, 1, 3, 20), isPerfect: false, calendar: cal)
        XCTAssertTrue(p.fullMoon)
        var other = AchievementProgress()
        other.recordSession(modes: [.review], date: date(2026, 1, 4, 20), isPerfect: false, calendar: cal)
        XCTAssertFalse(other.fullMoon)
    }

    func testComebackCountForKing() {
        let cal = Self.utc
        var p = AchievementProgress()
        p.recordSession(modes: [.review], date: date(2024, 3, 1, 12), isPerfect: false, calendar: cal)
        p.recordSession(modes: [.review], date: date(2024, 3, 5, 12), isPerfect: false, calendar: cal) // Comeback 1
        p.recordSession(modes: [.review], date: date(2024, 3, 20, 12), isPerfect: false, calendar: cal) // Comeback 2
        p.recordSession(modes: [.review], date: date(2024, 4, 1, 12), isPerfect: false, calendar: cal) // Comeback 3
        XCTAssertEqual(p.comebackCount, 3)
    }

    func testSprachmixThreeGroupsOneDay() {
        let cal = Self.utc
        var p = AchievementProgress()
        p.recordSession(modes: [.review], date: date(2024, 2, 1, 9), isPerfect: false, groups: ["A"], calendar: cal)
        p.recordSession(modes: [.review], date: date(2024, 2, 1, 10), isPerfect: false, groups: ["B"], calendar: cal)
        XCTAssertFalse(p.sprachmix)
        p.recordSession(modes: [.review], date: date(2024, 2, 1, 11), isPerfect: false, groups: ["C"], calendar: cal)
        XCTAssertTrue(p.sprachmix) // 3 verschiedene Gruppen am selben Tag
        // Am nächsten Tag ist der Gruppen-Puffer zurückgesetzt.
        p.recordSession(modes: [.review], date: date(2024, 2, 2, 9), isPerfect: false, groups: ["A"], calendar: cal)
        XCTAssertEqual(p.groupsToday, ["A"])
    }

    func testBossDefeatedFlagAndBadge() {
        let cal = Self.utc
        var p = AchievementProgress()
        // Normale (Nicht-Boss-)Runde setzt das Flag nicht.
        p.recordSession(modes: [.review], date: date(2024, 2, 1, 12), isPerfect: false, calendar: cal)
        XCTAssertFalse(p.bossDefeated)
        // Siegreiche Endgegner-Runde setzt das Flag.
        p.recordSession(modes: [.review], date: date(2024, 2, 1, 13), isPerfect: false,
                        bossDefeated: true, calendar: cal)
        XCTAssertTrue(p.bossDefeated)

        let metrics = AchievementMetrics.from(progress: p, learnedWords: 0, totalWords: 0, longestStreak: 0)
        XCTAssertTrue(metrics.bossDefeated)
        let badge = AchievementCatalog.all.first { $0.id == "bossDefeated" }
        XCTAssertNotNil(badge)
        XCTAssertTrue(badge!.isUnlocked(metrics))
    }

    func testMetaBadgeNeedsAllOthers() {
        let meta = AchievementCatalog.all.first { $0.requirement == .meta }
        XCTAssertNotNil(meta)
        XCTAssertFalse(meta!.isUnlocked(AchievementMetrics(unlockedBadges: 5, totalBadges: 10)))
        XCTAssertTrue(meta!.isUnlocked(AchievementMetrics(unlockedBadges: 10, totalBadges: 10)))
        // Ohne bekannte Gesamtzahl (Default-Metriken) darf Meta nicht auslösen.
        XCTAssertFalse(meta!.isUnlocked(AchievementMetrics()))
        XCTAssertEqual(meta!.progressText(AchievementMetrics(unlockedBadges: 3, totalBadges: 10)), "3 / 10")
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

    // MARK: - Gruppen-Meisterschaft (reine Auswertung)

    @MainActor
    func testGroupMasteryEmptyInput() {
        let result = AchievementService.groupMastery(from: [])
        XCTAssertFalse(result.any)
        XCTAssertFalse(result.all)
    }

    @MainActor
    func testGroupMasterySingleFullGroupAtMinSize() {
        // Genau die Mindestgröße, komplett gelernt → beide Ableitungen wahr.
        let min = AchievementService.themenMeisterMinSize
        let result = AchievementService.groupMastery(from: [(count: min, learned: min)])
        XCTAssertTrue(result.any)
        XCTAssertTrue(result.all)
    }

    @MainActor
    func testGroupMasterySmallFullGroupBelowTotalThreshold() {
        // Voll gelernt, aber zu klein (< MinSize) und Gesamtsumme < MinSize → nichts.
        let min = AchievementService.themenMeisterMinSize
        let result = AchievementService.groupMastery(from: [(count: min - 1, learned: min - 1)])
        XCTAssertFalse(result.any)
        XCTAssertFalse(result.all)
    }

    @MainActor
    func testGroupMasteryManySmallFullGroupsReachTotalThreshold() {
        // Jede Gruppe < MinSize (kein „any"), aber alle voll gelernt und Summe >= MinSize → „all".
        let min = AchievementService.themenMeisterMinSize
        let small = min - 1 // je < MinSize; zwei davon summieren >= MinSize
        let result = AchievementService.groupMastery(from: [(count: small, learned: small), (count: small, learned: small)])
        XCTAssertFalse(result.any)
        XCTAssertTrue(result.all)
    }

    @MainActor
    func testGroupMasteryOneMasteredOnePartial() {
        // Eine große Gruppe komplett, eine teils gelernt → „any", aber nicht „all".
        let min = AchievementService.themenMeisterMinSize
        let result = AchievementService.groupMastery(from: [(count: min + 1, learned: min + 1), (count: min - 1, learned: 1)])
        XCTAssertTrue(result.any)
        XCTAssertFalse(result.all)
    }

    @MainActor
    func testGroupMasteryIgnoresEmptyGroups() {
        // Leere Gruppen (count 0) zählen nicht mit und kippen „all" nicht.
        let min = AchievementService.themenMeisterMinSize
        let result = AchievementService.groupMastery(from: [(count: min, learned: min), (count: 0, learned: 0)])
        XCTAssertTrue(result.any)
        XCTAssertTrue(result.all)
    }

    @MainActor
    func testGroupMasteryBigGardenNeedsSizeAndFullLearning() {
        // „Voller Garten": erst ab gardenBloomMinSize komplett gelernt.
        let big = AchievementService.gardenBloomMinSize
        // Groß genug, aber nicht komplett gelernt → kein „big".
        XCTAssertFalse(AchievementService.groupMastery(from: [(count: big, learned: big - 1)]).big)
        // Komplett gelernt, aber zu klein → kein „big" (aber „any", da >= MinSize).
        XCTAssertFalse(AchievementService.groupMastery(from: [(count: big - 1, learned: big - 1)]).big)
        // Groß genug UND komplett gelernt → „big".
        XCTAssertTrue(AchievementService.groupMastery(from: [(count: big, learned: big)]).big)
    }

    // MARK: - Persistenz (AchievementStore)

    /// Sichert und leert die Achievement-Keys vor jedem Store-Test und stellt sie
    /// danach exakt wieder her, damit der geteilte App-Group-Container nicht leakt.
    private static let storeKeys = [
        AchievementKeys.unlockedIDs, AchievementKeys.unlockDates, AchievementKeys.progress,
        AchievementKeys.modesUsed, AchievementKeys.weekdays, AchievementKeys.sessions,
        AchievementKeys.perfectRounds, AchievementKeys.nightOwl, AchievementKeys.earlyBird
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
                if let value = savedDefaults[key], let value {
                    d.set(value, forKey: key)
                } else {
                    d.removeObject(forKey: key)
                }
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

    /// Regression: ein Speicherstand aus einer älteren App-Version (JSON ohne ein später
    /// ergänztes Feld) darf NICHT den gesamten Fortschritt auf den leeren Legacy-Fallback
    /// zurücksetzen. Das synthetisierte `Codable` würde hier `keyNotFound` werfen –
    /// abgefangen durch den fehlertoleranten `init(from:)`.
    func testProgressDecodesWhenNewerFieldIsMissing() throws {
        let cal = Self.utc
        var p = AchievementProgress()
        p.recordSession(modes: [.review, .writing], date: date(2024, 1, 10, 2), isPerfect: true,
                        isFlawless: true, newlyLearned: 1, currentStreak: 1, calendar: cal)
        XCTAssertTrue(p.flawlessToday) // wird gleich aus dem JSON entfernt

        // JSON eines älteren Builds simulieren: das jüngste Feld fehlt komplett.
        let full = try JSONEncoder().encode(p)
        var obj = try XCTUnwrap(try JSONSerialization.jsonObject(with: full) as? [String: Any])
        obj.removeValue(forKey: "flawlessToday")
        let trimmed = try JSONSerialization.data(withJSONObject: obj)

        withCleanStore {
            AppGroup.defaults.set(trimmed, forKey: AchievementKeys.progress)
            let loaded = AchievementStore.progress
            // Bestehender Fortschritt überlebt (kein Reset auf den leeren Legacy-Zustand).
            XCTAssertEqual(loaded.sessionsCompleted, p.sessionsCompleted)
            XCTAssertEqual(loaded.modesUsed, p.modesUsed)
            XCTAssertEqual(loaded.flawlessRun.best, p.flawlessRun.best)
            XCTAssertNotEqual(loaded, AchievementProgress()) // definitiv nicht der Default
            // Das fehlende Feld nimmt seinen Property-Default an.
            XCTAssertFalse(loaded.flawlessToday)
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

// MARK: - Live-Kombo (#90)

/// Als Extension ausgelagert, damit die Haupt-Klasse unter der `type_body_length`-Grenze bleibt.
extension AchievementTests {

    /// `recordSession(maxCombo:)` merkt sich das je höchste Kombo-Maximum – auch über
    /// mehrere Runden hinweg fällt es nie unter einen bereits erreichten Wert.
    func testRecordSessionTracksBestCombo() {
        let cal = Self.utc
        var p = AchievementProgress()
        p.recordSession(modes: [.review], date: date(2024, 1, 15, 14), isPerfect: false,
                        maxCombo: 4, calendar: cal)
        XCTAssertEqual(p.bestCombo, 4)
        // Höhere Kombo hebt das Maximum.
        p.recordSession(modes: [.review], date: date(2024, 1, 16, 14), isPerfect: false,
                        maxCombo: 12, calendar: cal)
        XCTAssertEqual(p.bestCombo, 12)
        // Niedrigere Kombo lässt das Maximum unberührt.
        p.recordSession(modes: [.review], date: date(2024, 1, 17, 14), isPerfect: false,
                        maxCombo: 3, calendar: cal)
        XCTAssertEqual(p.bestCombo, 12)
    }

    /// Eine Runde mit einer Kombo von ≥10 schaltet das „Kombo-Meister"-Badge frei.
    func testComboMasterUnlocksAtTen() {
        let master = Achievement(id: "comboMaster", category: .fun, emoji: "⚡️",
                                 requirement: .count(\.bestCombo, 10))
        XCTAssertFalse(master.isUnlocked(AchievementMetrics(bestCombo: 9)))
        XCTAssertTrue(master.isUnlocked(AchievementMetrics(bestCombo: 10)))
    }

    /// `bestCombo` übersteht den JSON-Round-Trip durch die Defaults.
    func testBestComboRoundTripsThroughDefaults() {
        withCleanStore {
            let cal = Self.utc
            var p = AchievementProgress()
            p.recordSession(modes: [.review], date: date(2024, 1, 10, 14), isPerfect: false,
                            maxCombo: 7, calendar: cal)
            AchievementStore.progress = p
            XCTAssertEqual(AchievementStore.progress.bestCombo, 7)
        }
    }
}
