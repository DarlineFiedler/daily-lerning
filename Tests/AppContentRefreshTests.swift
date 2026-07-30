@testable import DailyHangul
import XCTest

/// Prüft die Change-Detection beim Vordergrund-Wechsel
/// (`AppContentRefresh.shouldRefreshOnActive`): voll auffrischen nur beim ersten Aufruf
/// oder bei einem Tageswechsel – reine App-Switches am selben Tag werden übersprungen.
@MainActor
final class AppContentRefreshTests: XCTestCase {

    private let calendar = Calendar.current

    /// Beim ersten Aufruf (kein bekannter letzter Refresh) muss immer aufgefrischt werden,
    /// damit Widget/Badge nach einem Kaltstart garantiert frisch sind.
    func testRefreshesOnFirstCall() {
        XCTAssertTrue(AppContentRefresh.shouldRefreshOnActive(lastRefreshDay: nil, now: .now))
    }

    /// Gleicher Kalendertag (nur andere Uhrzeit) → reiner App-Switch → kein Refresh.
    func testSkipsWithinSameDay() {
        let morning = date(2026, 7, 30, hour: 8)
        let evening = date(2026, 7, 30, hour: 21)
        let lastDay = calendar.startOfDay(for: morning)
        XCTAssertFalse(AppContentRefresh.shouldRefreshOnActive(lastRefreshDay: lastDay, now: evening))
    }

    /// Neuer Kalendertag (Tageswechsel) → wieder auffrischen (Streak/Badge tagesbasiert).
    func testRefreshesOnNewDay() {
        let today = calendar.startOfDay(for: date(2026, 7, 30, hour: 23))
        let tomorrow = date(2026, 7, 31, hour: 1)
        XCTAssertTrue(AppContentRefresh.shouldRefreshOnActive(lastRefreshDay: today, now: tomorrow))
    }

    /// Springt die Uhr/Zeitzone zurück (früherer Tag), zählt das als Änderung → auffrischen.
    /// Entscheidend ist die Ungleichheit des Kalendertags, nicht „später".
    func testRefreshesWhenClockMovesBack() {
        let today = calendar.startOfDay(for: date(2026, 7, 30, hour: 12))
        let yesterday = date(2026, 7, 29, hour: 12)
        XCTAssertTrue(AppContentRefresh.shouldRefreshOnActive(lastRefreshDay: today, now: yesterday))
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }
}
