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

    private func record(_ log: WeeklyActivity, _ id: UUID, learned: Bool = false,
                        correct: Bool = true, on date: Date) -> WeeklyActivity {
        log.recording(wordID: id, becameLearned: learned, correct: correct, on: date, calendar: cal)
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

    // MARK: - Laufende Woche (Wochenziel)

    private func currentWeek(_ log: WeeklyActivity) -> (practiced: Int, learned: Int) {
        log.currentWeekTotals(asOf: cal.date(from: today)!, calendar: cal)
    }

    func testCurrentWeekCountsInProgressWeekDistinct() {
        let a = UUID(), b = UUID()
        var log = WeeklyActivity()
        log = record(log, a, on: day(2026, 7, 20)) // Mo (laufende Woche)
        log = record(log, a, on: day(2026, 7, 21)) // dasselbe Wort → kein Doppel
        log = record(log, b, on: day(2026, 7, 21)) // zweites Wort
        XCTAssertEqual(currentWeek(log).practiced, 2)
    }

    func testCurrentWeekSumsNewlyLearned() {
        var log = WeeklyActivity()
        log = record(log, UUID(), learned: true, on: day(2026, 7, 20))
        log = record(log, UUID(), learned: true, on: day(2026, 7, 23))
        log = record(log, UUID(), learned: false, on: day(2026, 7, 23))
        XCTAssertEqual(currentWeek(log).learned, 2)
    }

    func testCurrentWeekExcludesPreviousWeek() {
        // Eintrag der letzten abgeschlossenen Woche zählt NICHT zur laufenden Woche.
        var log = WeeklyActivity()
        log = record(log, UUID(), on: day(2026, 7, 14))
        XCTAssertEqual(currentWeek(log).practiced, 0)
    }

    func testEmptyLogHasNoCurrentWeekProgress() {
        let totals = currentWeek(WeeklyActivity())
        XCTAssertEqual(totals.practiced, 0)
        XCTAssertEqual(totals.learned, 0)
    }

    // MARK: - Heutiger Tag (Tagesziel)

    func testDayTotalsCountsOnlyThatDay() {
        let a = UUID(), b = UUID()
        let todayDate = cal.date(from: today)! // Do 23.7.
        var log = WeeklyActivity()
        log = record(log, a, on: todayDate)
        log = record(log, b, on: day(2026, 7, 21)) // anderer Tag derselben Woche
        let totals = log.dayTotals(on: todayDate, calendar: cal)
        XCTAssertEqual(totals.practiced, 1)
    }

    func testDayTotalsIsZeroForDayWithoutEntry() {
        var log = WeeklyActivity()
        log = record(log, UUID(), on: day(2026, 7, 21))
        let totals = log.dayTotals(on: cal.date(from: today)!, calendar: cal)
        XCTAssertEqual(totals.practiced, 0)
        XCTAssertEqual(totals.learned, 0)
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

    func testEntriesWithinRetentionAreKept() {
        let base = cal.date(from: today)!
        var log = WeeklyActivity()
        // Eintrag knapp innerhalb des (jetzt 91-tägigen) Fensters bleibt erhalten.
        let within = cal.date(byAdding: .day, value: -(WeeklyActivity.retentionDays - 1), to: base)!
        log = record(log, UUID(), on: within)
        log = record(log, UUID(), on: base) // prunt relativ zu heute
        XCTAssertTrue(log.days.contains { cal.isDate($0.day, inSameDayAs: within) },
                      "Einträge innerhalb retentionDays bleiben erhalten")
        XCTAssertEqual(WeeklyActivity.retentionDays, 91)
    }

    // MARK: - Wochenserie (Lernkurve #40)

    private func series(_ log: WeeklyActivity, weeks: Int) -> [WeekBucket] {
        log.weeklySeries(weeks: weeks, asOf: cal.date(from: today)!, calendar: cal)
    }

    func testWeeklySeriesReturnsRequestedNumberOfWeeksOldestFirst() {
        let buckets = series(WeeklyActivity(), weeks: 12)
        XCTAssertEqual(buckets.count, 12)
        // Aufsteigend sortiert (älteste zuerst), lückenlos im 7-Tage-Raster.
        for pair in zip(buckets, buckets.dropFirst()) {
            XCTAssertEqual(cal.date(byAdding: .day, value: 7, to: pair.0.weekStart), pair.1.weekStart)
        }
        // Letzter Bucket ist die laufende Woche (Mo 20.7.).
        XCTAssertEqual(buckets.last?.weekStart, cal.startOfWeek(for: cal.date(from: today)!))
    }

    func testWeeklySeriesFillsWeeksWithoutActivityAsZero() {
        var log = WeeklyActivity()
        log = record(log, UUID(), on: day(2026, 7, 21)) // nur laufende Woche
        let buckets = series(log, weeks: 4)
        XCTAssertEqual(buckets.last?.practiced, 1)
        // Die drei Wochen davor ohne Aktivität → 0, keine Auslassung.
        XCTAssertEqual(buckets.dropLast().map(\.practiced), [0, 0, 0])
        XCTAssertFalse(buckets.dropLast().contains { $0.hasActivity })
    }

    func testWeeklySeriesCountsDistinctPractisedPerWeek() {
        let a = UUID(), b = UUID()
        var log = WeeklyActivity()
        log = record(log, a, on: day(2026, 7, 14))
        log = record(log, a, on: day(2026, 7, 15)) // dasselbe Wort → kein Doppel
        log = record(log, b, on: day(2026, 7, 15))
        // Woche 13.–19.7. enthält 2 distinct Wörter.
        let week = series(log, weeks: 12).first { cal.isDate($0.weekStart, inSameDayAs: day(2026, 7, 13)) }
        XCTAssertEqual(week?.practiced, 2)
    }

    // MARK: - Trefferquote (Lernkurve #40)

    func testWeeklyAccuracyAggregatesCorrectAndWrong() {
        var log = WeeklyActivity()
        log = record(log, UUID(), correct: true, on: day(2026, 7, 14))
        log = record(log, UUID(), correct: true, on: day(2026, 7, 15))
        log = record(log, UUID(), correct: false, on: day(2026, 7, 16))
        let week = series(log, weeks: 12).first { cal.isDate($0.weekStart, inSameDayAs: day(2026, 7, 13)) }
        XCTAssertEqual(week?.correct, 2)
        XCTAssertEqual(week?.wrong, 1)
        XCTAssertEqual(week?.accuracy, 67) // 2/3 gerundet
    }

    func testWeeklyAccuracyIsNilWithoutAnswers() {
        let buckets = series(WeeklyActivity(), weeks: 4)
        XCTAssertTrue(buckets.allSatisfy { $0.accuracy == nil })
    }

    // MARK: - Tagesmengen (Heatmap #54)

    private func daily(_ log: WeeklyActivity, days: Int) -> [Date: Int] {
        log.dailyPracticed(days: days, asOf: cal.date(from: today)!, calendar: cal)
    }

    func testDailyPractisedReturnsCountsPerDay() {
        let a = UUID(), b = UUID()
        var log = WeeklyActivity()
        log = record(log, a, on: day(2026, 7, 21))
        log = record(log, b, on: day(2026, 7, 21))
        log = record(log, a, on: day(2026, 7, 22))
        let counts = daily(log, days: 91)
        XCTAssertEqual(counts[cal.startOfDay(for: day(2026, 7, 21))], 2)
        XCTAssertEqual(counts[cal.startOfDay(for: day(2026, 7, 22))], 1)
    }

    func testDailyPractisedOmitsDaysWithoutActivity() {
        var log = WeeklyActivity()
        log = record(log, UUID(), on: day(2026, 7, 21))
        let counts = daily(log, days: 91)
        XCTAssertNil(counts[cal.startOfDay(for: day(2026, 7, 20))]) // Aufrufer wertet als 0
        XCTAssertEqual(counts.count, 1)
    }

    func testDailyPractisedExcludesEntriesOutsideWindow() {
        var log = WeeklyActivity()
        // 40 Tage zurück liegt außerhalb eines 30-Tage-Fensters.
        let outside = cal.date(byAdding: .day, value: -40, to: cal.date(from: today)!)!
        log = record(log, UUID(), on: outside)
        log = record(log, UUID(), on: day(2026, 7, 21))
        XCTAssertEqual(daily(log, days: 30).count, 1)
    }

    // MARK: - Migration alter Logs (ohne Trefferquote-Felder)

    func testDecodingLegacyDayEntryDefaultsAccuracyToZero() throws {
        // Alt-JSON ohne correctCount/wrongCount (vor der Trefferquote-Erweiterung).
        let json = """
        {"days":[{"day":774316800,"practicedIDs":[],"newlyLearned":3}]}
        """
        let decoded = try JSONDecoder().decode(WeeklyActivity.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.days.count, 1)
        XCTAssertEqual(decoded.days[0].newlyLearned, 3)
        XCTAssertEqual(decoded.days[0].correctCount, 0)
        XCTAssertEqual(decoded.days[0].wrongCount, 0)
    }
}
