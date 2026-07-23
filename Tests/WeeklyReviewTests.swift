@testable import DailyHangul
import XCTest

final class WeeklyReviewTests: XCTestCase {
    private var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.firstWeekday = 2 // Montag
        c.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return c
    }()

    private func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: 10))!
    }

    // Referenz-„heute": Do 23.7.2026.
    // → aktuelle Woche ab Mo 20.7.; letzte abgeschlossene Woche = 13.–19.7.;
    //   Vorwoche = 6.–12.7.
    private let today = DateComponents(year: 2026, month: 7, day: 23)

    private func review(_ log: WeeklyActivity, streak: Int = 0) -> WeeklyReview {
        log.lastCompletedWeekReview(asOf: cal.date(from: today)!, calendar: cal, streak: streak)
    }

    private func record(_ log: WeeklyActivity, _ id: UUID, learned: Bool = false, on date: Date) -> WeeklyActivity {
        log.recording(wordID: id, becameLearned: learned, on: date, calendar: cal)
    }

    // MARK: - Leerer Log / Neuinstallation

    func testEmptyLogHasNoActivity() {
        let r = review(WeeklyActivity())
        XCTAssertEqual(r.practicedCount, 0)
        XCTAssertEqual(r.newlyLearnedCount, 0)
        XCTAssertNil(r.deltaPercent)
        XCTAssertFalse(r.hasActivity)
    }

    // MARK: - Zählung der letzten abgeschlossenen Woche

    func testDistinctWordsAreCountedOncePerWeek() {
        let a = UUID(), b = UUID()
        var log = WeeklyActivity()
        log = record(log, a, on: day(2026, 7, 14)) // Di
        log = record(log, a, on: day(2026, 7, 15)) // dasselbe Wort erneut → kein Doppel
        log = record(log, b, on: day(2026, 7, 15)) // zweites Wort
        let r = review(log)
        XCTAssertEqual(r.practicedCount, 2)
        XCTAssertTrue(r.hasActivity)
    }

    func testSameWordSameDayCountedOnce() {
        let a = UUID()
        var log = WeeklyActivity()
        log = record(log, a, on: day(2026, 7, 14))
        log = record(log, a, on: day(2026, 7, 14))
        XCTAssertEqual(review(log).practicedCount, 1)
    }

    func testNewlyLearnedIsSummedAcrossTheWeek() {
        var log = WeeklyActivity()
        log = record(log, UUID(), learned: true, on: day(2026, 7, 14))
        log = record(log, UUID(), learned: true, on: day(2026, 7, 16))
        log = record(log, UUID(), learned: false, on: day(2026, 7, 16))
        XCTAssertEqual(review(log).newlyLearnedCount, 2)
    }

    func testCurrentWeekIsNotCountedInReview() {
        // 21.7. liegt in der laufenden Woche → gehört nicht zum Rückblick.
        var log = WeeklyActivity()
        log = record(log, UUID(), on: day(2026, 7, 21))
        XCTAssertEqual(review(log).practicedCount, 0)
    }

    func testStreakIsPassedThrough() {
        XCTAssertEqual(review(WeeklyActivity(), streak: 7).streak, 7)
    }

    // MARK: - Vergleich zur Vorwoche

    func testDeltaComparesToPreviousWeek() {
        var log = WeeklyActivity()
        log = record(log, UUID(), on: day(2026, 7, 8)) // Vorwoche: 1 Wort
        log = record(log, UUID(), on: day(2026, 7, 14)) // letzte Woche: 2 Wörter
        log = record(log, UUID(), on: day(2026, 7, 15))
        XCTAssertEqual(review(log).deltaPercent, 100) // +100 %
    }

    func testDeltaIsNilWithoutPreviousWeekData() {
        var log = WeeklyActivity()
        log = record(log, UUID(), on: day(2026, 7, 14)) // nur letzte Woche
        XCTAssertNil(review(log).deltaPercent)
    }

    func testDeltaNegativeWhenLessThanPreviousWeek() {
        let a = UUID(), b = UUID(), c = UUID(), d = UUID()
        var log = WeeklyActivity()
        for id in [a, b, c, d] { log = record(log, id, on: day(2026, 7, 8)) } // Vorwoche: 4
        log = record(log, UUID(), on: day(2026, 7, 14)) // letzte Woche: 1
        XCTAssertEqual(review(log).deltaPercent, -75) // (1-4)/4 = -75 %
    }

    // MARK: - Aufbewahrung

    func testOldEntriesArePrunedOnRecord() {
        let old = day(2026, 6, 1)
        var log = WeeklyActivity()
        log = record(log, UUID(), on: old)
        // Ein neuer Eintrag weit später prunt den alten (> retentionDays entfernt).
        let recent = cal.date(byAdding: .day, value: WeeklyActivity.retentionDays + 1, to: old)!
        log = record(log, UUID(), on: recent)
        XCTAssertFalse(log.days.contains { cal.isDate($0.day, inSameDayAs: old) },
                       "Einträge älter als retentionDays werden entfernt")
    }
}
