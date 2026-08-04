@testable import DailyHangul
import XCTest

/// Tests der reinen Ziel-Historie (`GoalHistory`) – Snapshot-Idempotenz, Wochen-Lookup,
/// Aufbewahrung und migrationssicheres Decoding.
final class GoalHistoryTests: XCTestCase {
    private var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.firstWeekday = 2 // Montag
        c.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return c
    }()

    private func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: 10))!
    }

    private func snapshot(_ history: GoalHistory, daily: Int, weekly: Int,
                          metric: GoalMetric = .practiced, on date: Date) -> GoalHistory {
        history.recordingSnapshot(dailyTarget: daily, weeklyTarget: weekly,
                                  metric: metric, on: date, calendar: cal)
    }

    // MARK: - Snapshot

    func testSnapshotAddsEntryForDay() {
        let h = snapshot(GoalHistory(), daily: 5, weekly: 30, on: day(2026, 7, 23))
        let entry = h.entry(on: day(2026, 7, 23), calendar: cal)
        XCTAssertEqual(entry?.dailyTarget, 5)
        XCTAssertEqual(entry?.weeklyTarget, 30)
        XCTAssertEqual(entry?.metricRaw, GoalMetric.practiced.rawValue)
    }

    func testSnapshotIsIdempotentPerDayAndKeepsLatest() {
        var h = snapshot(GoalHistory(), daily: 5, weekly: 30, on: day(2026, 7, 23))
        // Zweiter Snapshot am selben Tag überschreibt den Eintrag (kein Duplikat).
        h = snapshot(h, daily: 8, weekly: 50, on: day(2026, 7, 23))
        XCTAssertEqual(h.days.count, 1)
        XCTAssertEqual(h.entry(on: day(2026, 7, 23), calendar: cal)?.dailyTarget, 8)
        XCTAssertEqual(h.entry(on: day(2026, 7, 23), calendar: cal)?.weeklyTarget, 50)
    }

    func testSnapshotSkipsZeroGoalDayWithoutExistingEntry() {
        // Kein aktives Ziel und noch kein Eintrag → kein reiner Null-Eintrag.
        let h = snapshot(GoalHistory(), daily: 0, weekly: 0, on: day(2026, 7, 23))
        XCTAssertTrue(h.days.isEmpty)
        XCTAssertNil(h.entry(on: day(2026, 7, 23), calendar: cal))
    }

    func testSnapshotClearsExistingEntryWhenGoalRemoved() {
        // Erst Ziel gesetzt, dann auf 0 zurück: der bestehende Eintrag wird auf 0
        // aktualisiert (Tag „ausgeschaltet"), nicht gelöscht.
        var h = snapshot(GoalHistory(), daily: 5, weekly: 30, on: day(2026, 7, 23))
        h = snapshot(h, daily: 0, weekly: 0, on: day(2026, 7, 23))
        XCTAssertEqual(h.days.count, 1)
        XCTAssertEqual(h.entry(on: day(2026, 7, 23), calendar: cal)?.dailyTarget, 0)
        XCTAssertEqual(h.entry(on: day(2026, 7, 23), calendar: cal)?.weeklyTarget, 0)
    }

    func testEntryIsNilForDayWithoutSnapshot() {
        let h = snapshot(GoalHistory(), daily: 5, weekly: 30, on: day(2026, 7, 23))
        XCTAssertNil(h.entry(on: day(2026, 7, 22), calendar: cal))
    }

    // MARK: - Wochen-Lookup

    func testLatestEntryInWeekPicksMostRecentDay() {
        var h = snapshot(GoalHistory(), daily: 3, weekly: 20, on: day(2026, 7, 20)) // Mo
        h = snapshot(h, daily: 6, weekly: 40, on: day(2026, 7, 22)) // Mi (jünger)
        let weekStart = cal.startOfWeek(for: day(2026, 7, 22))
        XCTAssertEqual(h.latestEntry(inWeekStarting: weekStart, calendar: cal)?.weeklyTarget, 40)
    }

    func testLatestEntryInWeekIsNilWhenNoEntry() {
        let h = snapshot(GoalHistory(), daily: 3, weekly: 20, on: day(2026, 7, 13)) // Vorwoche
        let weekStart = cal.startOfWeek(for: day(2026, 7, 22))
        XCTAssertNil(h.latestEntry(inWeekStarting: weekStart, calendar: cal))
    }

    // MARK: - Aufbewahrung

    func testOldEntriesArePrunedOnSnapshot() {
        let old = day(2026, 4, 1)
        var h = snapshot(GoalHistory(), daily: 1, weekly: 5, on: old)
        let recent = cal.date(byAdding: .day, value: GoalHistory.retentionDays + 1, to: old)!
        h = snapshot(h, daily: 1, weekly: 5, on: recent)
        XCTAssertFalse(h.days.contains { cal.isDate($0.day, inSameDayAs: old) })
    }

    // MARK: - Migration

    func testDecodingLegacyEntryDefaultsMissingFields() throws {
        // Alt-JSON mit nur `day` – fehlende Zielfelder fallen auf neutrale Werte zurück.
        let json = """
        {"days":[{"day":774316800}]}
        """
        let decoded = try JSONDecoder().decode(GoalHistory.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.days.count, 1)
        XCTAssertEqual(decoded.days[0].dailyTarget, 0)
        XCTAssertEqual(decoded.days[0].weeklyTarget, 0)
        XCTAssertEqual(decoded.days[0].metricRaw, GoalMetric.practiced.rawValue)
    }
}
