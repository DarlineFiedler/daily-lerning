@testable import DailyHangul
import XCTest

final class StreakTests: XCTestCase {
    private let cal = Calendar(identifier: .gregorian)

    private func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: 10))!
    }

    func testFirstActivityStartsAtOne() {
        let s = StreakStore.nextStreak(lastActiveDay: nil, current: 0, today: day(2026, 7, 16), calendar: cal)
        XCTAssertEqual(s, 1)
    }

    func testSameDayIsIdempotent() {
        let s = StreakStore.nextStreak(lastActiveDay: day(2026, 7, 16), current: 5, today: day(2026, 7, 16), calendar: cal)
        XCTAssertEqual(s, 5)
    }

    func testConsecutiveDayIncrements() {
        let s = StreakStore.nextStreak(lastActiveDay: day(2026, 7, 15), current: 5, today: day(2026, 7, 16), calendar: cal)
        XCTAssertEqual(s, 6)
    }

    func testGapResetsToOne() {
        let s = StreakStore.nextStreak(lastActiveDay: day(2026, 7, 13), current: 5, today: day(2026, 7, 16), calendar: cal)
        XCTAssertEqual(s, 1)
    }

    func testStreakAliveTodayOrYesterday() {
        XCTAssertTrue(StreakStore.isStreakAlive(lastActiveDay: day(2026, 7, 16), today: day(2026, 7, 16), calendar: cal))
        XCTAssertTrue(StreakStore.isStreakAlive(lastActiveDay: day(2026, 7, 15), today: day(2026, 7, 16), calendar: cal))
        XCTAssertFalse(StreakStore.isStreakAlive(lastActiveDay: day(2026, 7, 14), today: day(2026, 7, 16), calendar: cal))
        XCTAssertFalse(StreakStore.isStreakAlive(lastActiveDay: nil, today: day(2026, 7, 16), calendar: cal))
    }
}
