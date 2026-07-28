@testable import DailyHangul
import XCTest

final class DailyChallengeTests: XCTestCase {
    private var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.firstWeekday = 2 // Montag
        c.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return c
    }()

    private func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: 10))!
    }

    /// Fortschritt mit „heute" (`day`) als aktivem Tagespuffer-Datum.
    private func progress(day: Date,
                          modes: Set<String> = [],
                          sessions: Int = 0,
                          newWords: Int = 0,
                          groups: Set<String> = [],
                          flawless: Bool = false) -> AchievementProgress {
        var p = AchievementProgress()
        p.currentDay = cal.startOfDay(for: day)
        p.modesToday = modes
        p.sessionsToday = sessions
        p.newWordsToday = newWords
        p.groupsToday = groups
        p.flawlessToday = flawless
        return p
    }

    // MARK: - Auswahl

    func testSameDayPicksSameChallenge() {
        let index = DailyChallengeCalendar.todayIndex(now: day(2026, 7, 28), calendar: cal)
        let a = DailyChallengeCatalog.forDay(index: index)
        let b = DailyChallengeCatalog.forDay(index: index)
        XCTAssertEqual(a, b)
    }

    func testSelectionIsDeterministicButRotates() {
        // Über einen vollen Zyklus (Kataloggröße) kommt jede Challenge genau einmal dran.
        let count = DailyChallengeCatalog.all.count
        let picks = (0 ..< count).map { DailyChallengeCatalog.forDay(index: $0).id }
        XCTAssertEqual(Set(picks).count, count, "Innerhalb eines Zyklus jede Challenge genau einmal")
    }

    func testAdjacentDaysDiffer() {
        let i = DailyChallengeCalendar.todayIndex(now: day(2026, 7, 28), calendar: cal)
        XCTAssertNotEqual(DailyChallengeCatalog.forDay(index: i),
                          DailyChallengeCatalog.forDay(index: i + 1))
    }

    // MARK: - Erfüllung (aus dem Tagespuffer)

    func testModesChallengeSatisfaction() {
        let challenge = DailyChallenge(id: "modes", emoji: "🎨", metric: .modes, target: 3)
        let today = day(2026, 7, 28)
        let notYet = progress(day: today, modes: ["a", "b"])
        XCTAssertEqual(challenge.done(from: notYet, now: today, calendar: cal), 2)
        XCTAssertFalse(challenge.isSatisfied(from: notYet, now: today, calendar: cal))

        let done = progress(day: today, modes: ["a", "b", "c"])
        XCTAssertTrue(challenge.isSatisfied(from: done, now: today, calendar: cal))
    }

    func testFlawlessChallengeSatisfaction() {
        let challenge = DailyChallenge(id: "flawless", emoji: "✨", metric: .flawless, target: 1)
        let today = day(2026, 7, 28)
        XCTAssertFalse(challenge.isSatisfied(from: progress(day: today), now: today, calendar: cal))
        XCTAssertTrue(challenge.isSatisfied(from: progress(day: today, flawless: true), now: today, calendar: cal))
    }

    func testStaleBufferFromPastDayCountsAsZero() {
        // Puffer stammt von gestern (currentDay ≠ heute) → gilt als 0, bis der nächste
        // Session-Write ihn zurücksetzt.
        let challenge = DailyChallenge(id: "sessions", emoji: "🔁", metric: .sessions, target: 2)
        let yesterday = day(2026, 7, 27)
        let stale = progress(day: yesterday, sessions: 5)
        XCTAssertEqual(challenge.done(from: stale, now: day(2026, 7, 28), calendar: cal), 0)
        XCTAssertFalse(challenge.isSatisfied(from: stale, now: day(2026, 7, 28), calendar: cal))
    }

    // MARK: - Mini-Streak-Zustand

    func testCompletionOnConsecutiveDaysIncrementsRun() {
        var s = DailyChallengeState()
        s = s.recordingCompletion(on: day(2026, 7, 26), calendar: cal)
        s = s.recordingCompletion(on: day(2026, 7, 27), calendar: cal)
        s = s.recordingCompletion(on: day(2026, 7, 28), calendar: cal)
        XCTAssertEqual(s.run, 3)
        XCTAssertEqual(s.best, 3)
        XCTAssertEqual(s.totalCompleted, 3)
    }

    func testCompletionSameDayIsIdempotent() {
        var s = DailyChallengeState()
        s = s.recordingCompletion(on: day(2026, 7, 28), calendar: cal)
        s = s.recordingCompletion(on: day(2026, 7, 28), calendar: cal)
        XCTAssertEqual(s.run, 1)
        XCTAssertEqual(s.totalCompleted, 1, "Mehrfach am selben Tag zählt einmal")
    }

    func testGapResetsRunButKeepsBestAndTotal() {
        var s = DailyChallengeState()
        s = s.recordingCompletion(on: day(2026, 7, 25), calendar: cal)
        s = s.recordingCompletion(on: day(2026, 7, 26), calendar: cal) // run 2
        s = s.recordingCompletion(on: day(2026, 7, 28), calendar: cal) // Lücke (27. verpasst)
        XCTAssertEqual(s.run, 1, "Verpasster Tag setzt den Mini-Streak folgenlos zurück")
        XCTAssertEqual(s.best, 2)
        XCTAssertEqual(s.totalCompleted, 3)
    }

    func testDisplayStreakZeroAfterMissedDay() {
        var s = DailyChallengeState()
        s = s.recordingCompletion(on: day(2026, 7, 26), calendar: cal)
        // Heute ist der 28. → gestern (27.) nicht erfüllt → Anzeige 0.
        XCTAssertEqual(s.displayStreak(asOf: day(2026, 7, 28), calendar: cal), 0)
        // Am Folgetag der Erfüllung noch sichtbar.
        XCTAssertEqual(s.displayStreak(asOf: day(2026, 7, 27), calendar: cal), 1)
    }

    // MARK: - Store (Persistenz über AppGroup.defaults)

    /// Baut einen Fortschritt, der die gegebene Challenge für `day` erfüllt – nutzt
    /// `Calendar.current`, passend zu den Store-Defaults.
    private func satisfying(_ c: DailyChallenge, day: Date) -> AchievementProgress {
        var p = AchievementProgress()
        p.currentDay = Calendar.current.startOfDay(for: day)
        switch c.metric {
        case .modes: p.modesToday = Set((0 ..< c.target).map(String.init))
        case .sessions: p.sessionsToday = c.target
        case .newWords: p.newWordsToday = c.target
        case .groups: p.groupsToday = Set((0 ..< c.target).map(String.init))
        case .flawless: p.flawlessToday = true
        }
        return p
    }

    override func setUp() {
        super.setUp()
        AppGroup.defaults.removeObject(forKey: DailyChallengeKeys.state)
    }

    override func tearDown() {
        AppGroup.defaults.removeObject(forKey: DailyChallengeKeys.state)
        super.tearDown()
    }

    func testStoreRegistersCompletionIdempotentlyAndPersistsStreak() {
        let now = Date.now
        let challenge = DailyChallengeStore.today(now: now)
        let p = satisfying(challenge, day: now)

        let unmet = DailyChallengeStore.snapshot(progress: AchievementProgress(), now: now)
        XCTAssertFalse(unmet.satisfied)

        let met = DailyChallengeStore.snapshot(progress: p, now: now)
        XCTAssertTrue(met.satisfied)
        XCTAssertEqual(met.challenge, challenge)

        DailyChallengeStore.registerCompletionIfNeeded(progress: p, on: now)
        XCTAssertEqual(DailyChallengeStore.totalCompleted, 1)
        XCTAssertEqual(DailyChallengeStore.displayStreak(asOf: now), 1)

        // Mehrfach am selben Tag zählt einmal.
        DailyChallengeStore.registerCompletionIfNeeded(progress: p, on: now)
        XCTAssertEqual(DailyChallengeStore.totalCompleted, 1)
    }

    func testStoreDoesNotRegisterWhenUnmet() {
        let now = Date.now
        DailyChallengeStore.registerCompletionIfNeeded(progress: AchievementProgress(), on: now)
        XCTAssertEqual(DailyChallengeStore.totalCompleted, 0)
        XCTAssertEqual(DailyChallengeStore.displayStreak(asOf: now), 0)
    }
}
