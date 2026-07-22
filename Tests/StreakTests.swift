@testable import DailyHangul
import XCTest

final class StreakTests: XCTestCase {
    private var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.firstWeekday = 2 // Montag
        c.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return c
    }()

    private let maxJokers = StreakStore.maxJokers // 3

    private func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: 10))!
    }

    /// Frischer Zustand mit gesetztem Wochen-Anker (keine Erst-Vergabe), damit
    /// Grant-Effekte in Streak-Tests nicht stören. Optional Startjoker.
    private func state(current: Int = 0, last: Date?, jokers: Int = 0, anchorWeekOf date: Date) -> StreakState {
        StreakState(current: current, longest: current, lastActiveDay: last,
                    jokers: jokers, weekAnchor: cal.startOfWeek(for: date), jokerUses: [])
    }

    private func register(_ s: StreakState, on date: Date) -> StreakState {
        s.registeringActivity(on: date, calendar: cal, maxJokers: maxJokers)
    }

    // MARK: - Streak-Grundverhalten

    func testFirstActivityStartsAtOneAndGrantsStartJoker() {
        let s = register(StreakState(), on: day(2026, 7, 16))
        XCTAssertEqual(s.current, 1)
        XCTAssertEqual(s.jokers, 1, "Beim ersten Mal gibt es sofort einen Startjoker")
    }

    func testSameDayIsIdempotent() {
        let start = state(current: 5, last: day(2026, 7, 16), anchorWeekOf: day(2026, 7, 16))
        let s = register(start, on: day(2026, 7, 16))
        XCTAssertEqual(s.current, 5)
    }

    func testConsecutiveDayIncrements() {
        let start = state(current: 5, last: day(2026, 7, 15), anchorWeekOf: day(2026, 7, 15))
        let s = register(start, on: day(2026, 7, 16))
        XCTAssertEqual(s.current, 6)
    }

    // MARK: - Joker rettet die Streak

    func testGapWithoutJokerResetsToOne() {
        let start = state(current: 5, last: day(2026, 7, 13), jokers: 0, anchorWeekOf: day(2026, 7, 13))
        let s = register(start, on: day(2026, 7, 16)) // 14. + 15. verpasst → 2 Joker nötig
        XCTAssertEqual(s.current, 1)
        XCTAssertEqual(s.jokers, 0)
    }

    func testOneMissedDayIsBridgedByJoker() {
        let start = state(current: 5, last: day(2026, 7, 15), jokers: 2, anchorWeekOf: day(2026, 7, 15))
        let s = register(start, on: day(2026, 7, 17)) // 16. verpasst → 1 Joker
        XCTAssertEqual(s.current, 6, "Streak läuft weiter")
        XCTAssertEqual(s.jokers, 1, "Ein Joker verbraucht")
        XCTAssertEqual(s.jokerUses.map { cal.startOfDay(for: $0) }, [cal.startOfDay(for: day(2026, 7, 16))])
    }

    func testTwoMissedDaysConsumeTwoJokers() {
        let start = state(current: 4, last: day(2026, 7, 13), jokers: 2, anchorWeekOf: day(2026, 7, 13))
        let s = register(start, on: day(2026, 7, 16)) // 14. + 15. verpasst
        XCTAssertEqual(s.current, 5)
        XCTAssertEqual(s.jokers, 0)
        XCTAssertEqual(s.jokerUses.count, 2)
    }

    func testGapLargerThanJokersResetsAndKeepsJokers() {
        let start = state(current: 9, last: day(2026, 7, 12), jokers: 1, anchorWeekOf: day(2026, 7, 16))
        let s = register(start, on: day(2026, 7, 16)) // 3 Tage verpasst, nur 1 Joker
        XCTAssertEqual(s.current, 1, "Nicht genug Joker → Reset")
        XCTAssertEqual(s.jokers, 1, "Joker bleiben erhalten, wenn sie nicht reichen")
        XCTAssertTrue(s.jokerUses.isEmpty)
    }

    // MARK: - Wöchentliche Joker-Vergabe

    func testWeeklyJokerGrantedEachWeek() {
        var s = StreakState(jokers: 0, weekAnchor: cal.startOfWeek(for: day(2026, 7, 6))) // Mo 6.7.
        s = s.grantingJokers(asOf: day(2026, 7, 13), calendar: cal, max: maxJokers) // +1 Woche
        XCTAssertEqual(s.jokers, 1)
        s = s.grantingJokers(asOf: day(2026, 7, 20), calendar: cal, max: maxJokers) // +1 Woche
        XCTAssertEqual(s.jokers, 2)
    }

    func testGrantIsIdempotentWithinSameWeek() {
        var s = StreakState(jokers: 1, weekAnchor: cal.startOfWeek(for: day(2026, 7, 6)))
        s = s.grantingJokers(asOf: day(2026, 7, 7), calendar: cal, max: maxJokers)
        s = s.grantingJokers(asOf: day(2026, 7, 9), calendar: cal, max: maxJokers)
        XCTAssertEqual(s.jokers, 1, "Innerhalb derselben Woche keine weitere Vergabe")
    }

    func testJokersAreCappedAtMaximum() {
        var s = StreakState(jokers: 2, weekAnchor: cal.startOfWeek(for: day(2026, 7, 6)))
        // 5 Wochen später → +5, aber Deckel bei maxJokers
        s = s.grantingJokers(asOf: day(2026, 8, 10), calendar: cal, max: maxJokers)
        XCTAssertEqual(s.jokers, maxJokers)
    }

    func testMultipleElapsedWeeksGrantMultipleJokers() {
        var s = StreakState(jokers: 0, weekAnchor: cal.startOfWeek(for: day(2026, 7, 6)))
        s = s.grantingJokers(asOf: day(2026, 7, 20), calendar: cal, max: maxJokers) // 2 Wochen → +2
        XCTAssertEqual(s.jokers, 2)
    }

    // MARK: - Sichtbarer Streak (mit Joker-Rettung)

    func testDisplayStreakAliveTodayOrYesterday() {
        let s = state(current: 7, last: day(2026, 7, 15), jokers: 0, anchorWeekOf: day(2026, 7, 16))
        XCTAssertEqual(s.displayStreak(asOf: day(2026, 7, 16), calendar: cal, maxJokers: maxJokers), 7)
    }

    func testDisplayStreakZeroWhenExpiredAndNoJoker() {
        let s = state(current: 7, last: day(2026, 7, 13), jokers: 0, anchorWeekOf: day(2026, 7, 16))
        XCTAssertEqual(s.displayStreak(asOf: day(2026, 7, 16), calendar: cal, maxJokers: maxJokers), 0)
    }

    func testDisplayStreakStillAliveWhenJokerCanSaveIt() {
        // Gestern verpasst, aber ein Joker könnte den einen Tag noch retten.
        let s = state(current: 7, last: day(2026, 7, 14), jokers: 1, anchorWeekOf: day(2026, 7, 16))
        XCTAssertEqual(s.displayStreak(asOf: day(2026, 7, 16), calendar: cal, maxJokers: maxJokers), 7)
    }

    func testDisplayStreakZeroWhenGapExceedsJokers() {
        let s = state(current: 7, last: day(2026, 7, 12), jokers: 1, anchorWeekOf: day(2026, 7, 16))
        XCTAssertEqual(s.displayStreak(asOf: day(2026, 7, 16), calendar: cal, maxJokers: maxJokers), 0)
    }

    func testDisplayStreakZeroWhenNeverActive() {
        let s = StreakState()
        XCTAssertEqual(s.displayStreak(asOf: day(2026, 7, 16), calendar: cal, maxJokers: maxJokers), 0)
    }

    // MARK: - Aktive Tage (Kalender)

    func testActiveDaysAreRecorded() {
        var s = register(StreakState(), on: day(2026, 7, 15))
        s = register(s, on: day(2026, 7, 16))
        s = register(s, on: day(2026, 7, 16)) // selber Tag → kein Duplikat
        XCTAssertEqual(s.activeDays.map { cal.startOfDay(for: $0) },
                       [cal.startOfDay(for: day(2026, 7, 15)), cal.startOfDay(for: day(2026, 7, 16))])
    }

    func testJokerBridgedDayIsNotAnActiveDay() {
        // 16. wird per Joker gerettet – zählt nicht als aktiver (gelernter) Tag.
        let start = state(current: 5, last: day(2026, 7, 15), jokers: 1, anchorWeekOf: day(2026, 7, 15))
        let s = register(start, on: day(2026, 7, 17))
        let active = Set(s.activeDays.map { cal.startOfDay(for: $0) })
        XCTAssertTrue(active.contains(cal.startOfDay(for: day(2026, 7, 17))))
        XCTAssertFalse(active.contains(cal.startOfDay(for: day(2026, 7, 16))))
    }

    // MARK: - Zusammenspiel: Wochenjoker deckt verpassten Tag beim nächsten Üben

    func testWeeklyJokerCoversMissedDayOnNextActivity() {
        // Aktiv So 12.7. (Streak 3), Mo 13.7. verpasst, wieder aktiv Di 14.7.
        // In der neuen Woche wird ein Joker vergeben, der den Montag rettet.
        var s = StreakState(current: 3, longest: 3, lastActiveDay: day(2026, 7, 12),
                            jokers: 0, weekAnchor: cal.startOfWeek(for: day(2026, 7, 12)))
        s = register(s, on: day(2026, 7, 14))
        XCTAssertEqual(s.current, 4, "Streak läuft dank Wochenjoker weiter")
        XCTAssertEqual(s.jokers, 0, "Der neu vergebene Wochenjoker wurde direkt verbraucht")
        XCTAssertEqual(s.jokerUses.count, 1)
    }
}
