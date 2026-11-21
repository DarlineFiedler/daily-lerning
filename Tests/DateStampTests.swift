@testable import DailyHangul
import XCTest

final class DateStampTests: XCTestCase {

    /// Fester Tag (10.11.2026), gebaut in der *Default-Zeitzone* – dieselbe, die der
    /// Formatter ohne explizite `timeZone` nutzt. So liefert der Stamp in jeder
    /// Geräte-/CI-Zeitzone denselben Kalendertag (kein UTC-Rollover z. B. in UTC+14).
    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 12
        return Calendar.current.date(from: components)!
    }

    func testStampHasFixedFormat() {
        XCTAssertEqual(DateStamp.fileStamp(date(2026, 11, 10)), "2026-11-10")
    }

    func testStampFormatIsStrictAsciiRegardlessOfLocale() {
        // Fester POSIX-Formatter → rein numerischer ASCII-Stamp, unabhängig von der
        // aktiven Geräte-Locale (keine lokalisierten Ziffern/Trenner).
        XCTAssertEqual(DateStamp.file.locale?.identifier, "en_US_POSIX")
        let stamp = DateStamp.fileStamp(date(2026, 1, 5))
        XCTAssertEqual(stamp, "2026-01-05")
        XCTAssertNotNil(stamp.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression))
    }

    func testDistinctDatesProduceDistinctStamps() {
        // Derselbe gecachte Formatter liefert für verschiedene Tage korrekt
        // verschiedene Stamps (Zustandslosigkeit zwischen Aufrufen).
        XCTAssertEqual(DateStamp.fileStamp(date(2026, 11, 10)), "2026-11-10")
        XCTAssertEqual(DateStamp.fileStamp(date(2025, 12, 31)), "2025-12-31")
    }
}
