@testable import DailyHangul
import XCTest

/// Prüft die Tageswechsel-Erkennung des Garten-Tabs (#160): Header-Datum und
/// tagesabhängige Werte werden nur bei einem echten Kalendertag-Wechsel aufgefrischt,
/// und der Header formatiert den übergebenen Tag (nicht pauschal `Date.now`).
@MainActor
final class GardenDayChangeTests: XCTestCase {

    /// Fester gregorianischer Kalender: Die Wochentag-Assertions („Montag"/„Dienstag")
    /// setzen gregorianische Jahre voraus – mit `Calendar.current` wäre „2026" auf einem
    /// Gerät mit buddhistischem/japanischem Kalender ein anderes Jahr. Zeitzone bleibt die
    /// des Geräts, damit `headerDateText` (formatiert in `.current`) denselben Tag sieht.
    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        return cal
    }()

    /// Gleicher Kalendertag (nur andere Uhrzeit) → kein Tageswechsel.
    func testSameDayIsNotNewDay() {
        let today = calendar.startOfDay(for: date(2026, 11, 23, hour: 8))
        XCTAssertFalse(GardenHomeView.isNewDay(current: today, now: date(2026, 11, 23, hour: 23), calendar: calendar))
    }

    /// Über Mitternacht (23:59 → 00:01) → Tageswechsel.
    func testCrossingMidnightIsNewDay() {
        let monday = calendar.startOfDay(for: date(2026, 11, 23, hour: 23, minute: 59))
        let tuesday = date(2026, 11, 24, hour: 0, minute: 1)
        XCTAssertTrue(GardenHomeView.isNewDay(current: monday, now: tuesday, calendar: calendar))
    }

    /// Uhr/Zeitzone zurück auf den Vortag zählt ebenfalls als Wechsel (Ungleichheit, nicht „später").
    func testClockMovingBackIsNewDay() {
        let today = calendar.startOfDay(for: date(2026, 11, 23, hour: 12))
        XCTAssertTrue(GardenHomeView.isNewDay(current: today, now: date(2026, 11, 22, hour: 12), calendar: calendar))
    }

    /// Der Header zeigt den Wochentag des übergebenen Tages – nach dem Wechsel also den neuen.
    func testHeaderDateTextFollowsGivenDay() {
        let locale = Locale(identifier: "de_DE")
        let monday = GardenHomeView.headerDateText(for: date(2026, 11, 23, hour: 12), locale: locale)
        let tuesday = GardenHomeView.headerDateText(for: date(2026, 11, 24, hour: 12), locale: locale)
        XCTAssertTrue(monday.contains("Montag"), monday)
        XCTAssertTrue(tuesday.contains("Dienstag"), tuesday)
        XCTAssertNotEqual(monday, tuesday)
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }
}
