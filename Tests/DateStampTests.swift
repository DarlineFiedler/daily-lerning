@testable import DailyHangul
import XCTest

final class DateStampTests: XCTestCase {

    /// Fester Zeitpunkt: 2026-11-10 12:00 UTC.
    private var knownDate: Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 11
        components.day = 10
        components.hour = 12
        components.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: components)!
    }

    func testStampHasFixedFormat() {
        XCTAssertEqual(DateStamp.fileStamp(knownDate), "2026-11-10")
    }

    func testStampIsLocaleIndependent() {
        // POSIX-Formatter → gleiche Ausgabe unabhängig von der aktuellen Geräte-Locale.
        let previous = DateStamp.file.locale
        XCTAssertEqual(previous?.identifier, "en_US_POSIX")
        XCTAssertEqual(DateStamp.fileStamp(knownDate), "2026-11-10")
    }

    func testCachedFormatterIsStableAcrossCalls() {
        // Mehrfacher Zugriff auf den gecachten `static let` liefert dieselbe Instanz …
        XCTAssertIdentical(DateStamp.file, DateStamp.file)
        // … und reproduzierbare Ausgabe.
        XCTAssertEqual(DateStamp.fileStamp(knownDate), DateStamp.fileStamp(knownDate))
    }
}
