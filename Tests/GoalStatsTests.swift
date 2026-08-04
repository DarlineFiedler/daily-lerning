@testable import DailyHangul
import XCTest

/// Tests der abgeleiteten Ziel-Statistik (`GoalStats`): Tages-Status, Ziel-Streak,
/// Erfüllungsquote und Wochenziel/Stern – aus Aktivität + Ziel-Historie kombiniert.
final class GoalStatsTests: XCTestCase {
    private var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.firstWeekday = 2 // Montag
        c.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return c
    }()

    // Referenz-„heute": Do 23.7.2026 (aktuelle Woche ab Mo 20.7.).
    private func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: 10))!
    }

    private var today: Date { day(2026, 7, 23) }

    /// Verbucht `count` distinct geübte Wörter am `date` (Tageswert = `count`).
    private func practiced(_ activity: WeeklyActivity, count: Int, learned: Int = 0,
                           on date: Date) -> WeeklyActivity {
        var a = activity
        for i in 0 ..< count {
            a = a.recording(wordID: UUID(), becameLearned: i < learned, correct: true,
                            on: date, calendar: cal)
        }
        return a
    }

    private func snap(_ history: GoalHistory, daily: Int, weekly: Int,
                      metric: GoalMetric = .practiced, on date: Date) -> GoalHistory {
        history.recordingSnapshot(dailyTarget: daily, weeklyTarget: weekly,
                                  metric: metric, on: date, calendar: cal)
    }

    private func stats(activity: WeeklyActivity = WeeklyActivity(),
                       history: GoalHistory = GoalHistory(),
                       daily: Int = 0, weekly: Int = 0,
                       metric: GoalMetric = .practiced) -> GoalStats {
        GoalStats(activity: activity, history: history,
                  currentDailyTarget: daily, currentWeeklyTarget: weekly,
                  currentMetric: metric, calendar: cal)
    }

    // MARK: - Tagesziel & Fallback

    func testDailyTargetUsesHistoryWhenPresent() {
        let h = snap(GoalHistory(), daily: 7, weekly: 0, on: day(2026, 7, 21))
        let s = stats(history: h, daily: 3)
        XCTAssertEqual(s.dailyTarget(on: day(2026, 7, 21)), 7)
    }

    func testDailyTargetFallsBackToCurrentWithoutHistory() {
        let s = stats(daily: 3)
        XCTAssertEqual(s.dailyTarget(on: day(2026, 7, 21)), 3)
    }

    func testValueUsesMetricOfTheDay() {
        // 2 geübt, davon 1 neu gelernt. Historie-Metrik = learned → Tageswert 1.
        let a = practiced(WeeklyActivity(), count: 2, learned: 1, on: day(2026, 7, 22))
        let h = snap(GoalHistory(), daily: 1, weekly: 0, metric: .learned, on: day(2026, 7, 22))
        let s = stats(activity: a, history: h)
        XCTAssertEqual(s.value(on: day(2026, 7, 22)), 1)
    }

    // MARK: - Tages-Status

    func testStatusReachedPartialMissedNoGoalUpcoming() {
        var a = practiced(WeeklyActivity(), count: 3, on: day(2026, 7, 21)) // erreicht (>=2)
        a = practiced(a, count: 1, on: day(2026, 7, 22)) // teilweise (0<1<2)
        var h = snap(GoalHistory(), daily: 2, weekly: 0, on: day(2026, 7, 21))
        h = snap(h, daily: 2, weekly: 0, on: day(2026, 7, 22))
        h = snap(h, daily: 2, weekly: 0, on: day(2026, 7, 23)) // heute, keine Aktivität → verpasst
        let s = stats(activity: a, history: h)
        XCTAssertEqual(s.status(on: day(2026, 7, 21), asOf: today), .reached)
        XCTAssertEqual(s.status(on: day(2026, 7, 22), asOf: today), .partial)
        XCTAssertEqual(s.status(on: day(2026, 7, 23), asOf: today), .missed)
        XCTAssertEqual(s.status(on: day(2026, 7, 20), asOf: today), .noGoal) // kein Ziel, kein Fallback
        XCTAssertEqual(s.status(on: day(2026, 7, 24), asOf: today), .upcoming)
    }

    // MARK: - Ziel-Streak

    func testGoalStreakCountsConsecutiveReachedDays() {
        var a = WeeklyActivity()
        for d in 21 ... 23 { a = practiced(a, count: 1, on: day(2026, 7, d)) }
        let s = stats(activity: a, daily: 1) // Fallback-Ziel 1 für alle Tage
        XCTAssertEqual(s.goalStreak(asOf: today), 3) // 21,22,23
    }

    func testGoalStreakAllowsTodayPendingAndStartsYesterday() {
        var a = WeeklyActivity()
        a = practiced(a, count: 1, on: day(2026, 7, 21))
        a = practiced(a, count: 1, on: day(2026, 7, 22))
        // heute (23.) keine Aktivität → offen; Streak zählt ab gestern.
        let s = stats(activity: a, daily: 1)
        XCTAssertEqual(s.goalStreak(asOf: today), 2)
    }

    func testGoalStreakIsZeroWhenGapBreaksIt() {
        var a = WeeklyActivity()
        a = practiced(a, count: 1, on: day(2026, 7, 23)) // nur heute
        // 22. fehlt → gestern nicht erreicht; da heute erreicht ist, Streak = 1.
        let s = stats(activity: a, daily: 1)
        XCTAssertEqual(s.goalStreak(asOf: today), 1)
    }

    func testBestGoalStreakFindsLongestRun() {
        var a = WeeklyActivity()
        // Lauf 1: 14.,15. (2). Lücke 16. Lauf 2: 17.,18.,19. (3).
        for d in [14, 15, 17, 18, 19] { a = practiced(a, count: 1, on: day(2026, 7, d)) }
        let s = stats(activity: a, daily: 1)
        XCTAssertEqual(s.bestGoalStreak(asOf: today), 3)
    }

    // MARK: - Erfüllungsquote

    func testCompletionRateForMonth() {
        var a = WeeklyActivity()
        a = practiced(a, count: 2, on: day(2026, 7, 20)) // erreicht
        a = practiced(a, count: 2, on: day(2026, 7, 21)) // erreicht
        a = practiced(a, count: 1, on: day(2026, 7, 22)) // verfehlt (Ziel 2)
        var h = GoalHistory()
        for d in [20, 21, 22] { h = snap(h, daily: 2, weekly: 0, on: day(2026, 7, d)) }
        // currentDailyTarget = 0 → nur die 3 Tage mit Snapshot zählen.
        let s = stats(activity: a, history: h, daily: 0)
        XCTAssertEqual(s.completionRate(inMonthOf: today, asOf: today), 2.0 / 3.0)
    }

    func testCompletionRateIsNilWithoutAnyGoalDay() {
        let s = stats(daily: 0)
        XCTAssertNil(s.completionRate(inMonthOf: today, asOf: today))
    }

    // MARK: - Wochenziel / Stern

    func testWeekReachedWhenWeeklyTargetMet() {
        var a = WeeklyActivity()
        a = practiced(a, count: 3, on: day(2026, 7, 20)) // Mo
        a = practiced(a, count: 2, on: day(2026, 7, 21)) // Di → Woche gesamt 5
        let h = snap(GoalHistory(), daily: 0, weekly: 5, on: day(2026, 7, 21))
        let s = stats(activity: a, history: h)
        XCTAssertTrue(s.weekReached(weekStarting: cal.startOfWeek(for: today)))
    }

    func testWeekNotReachedBelowTarget() {
        let a = practiced(WeeklyActivity(), count: 3, on: day(2026, 7, 20))
        let h = snap(GoalHistory(), daily: 0, weekly: 5, on: day(2026, 7, 20))
        let s = stats(activity: a, history: h)
        XCTAssertFalse(s.weekReached(weekStarting: cal.startOfWeek(for: today)))
    }

    func testWeekNotReachedWithoutTarget() {
        let a = practiced(WeeklyActivity(), count: 3, on: day(2026, 7, 20))
        let s = stats(activity: a, weekly: 0) // kein Wochenziel
        XCTAssertFalse(s.weekReached(weekStarting: cal.startOfWeek(for: today)))
    }

    func testWeeklyGoalsReachedCountAcrossWeeks() {
        var a = WeeklyActivity()
        // Laufende Woche (ab 20.7.): 5 geübt → erreicht.
        a = practiced(a, count: 5, on: day(2026, 7, 20))
        // Letzte Woche (13.–19.): 5 geübt → erreicht.
        a = practiced(a, count: 5, on: day(2026, 7, 14))
        var h = GoalHistory()
        h = snap(h, daily: 0, weekly: 5, on: day(2026, 7, 20))
        h = snap(h, daily: 0, weekly: 5, on: day(2026, 7, 14))
        let s = stats(activity: a, history: h)
        XCTAssertEqual(s.weeklyGoalsReachedCount(weeks: 4, asOf: today), 2)
    }
}
