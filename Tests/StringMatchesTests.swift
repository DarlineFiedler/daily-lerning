@testable import DailyHangul
import XCTest

/// Prüft den gemeinsamen `String.matches(_:)`-Teilstringvergleich (groß-/klein- und
/// diakritika-unempfindlich) der Wortlisten-/Suche-Filterung.
final class StringMatchesTests: XCTestCase {

    func testCaseInsensitiveSubstring() {
        XCTAssertTrue("Hangul lernen".matches("LERNEN"))
        XCTAssertTrue("hangul".matches("ang"))
    }

    func testDiacriticInsensitive() {
        XCTAssertTrue("café".matches("cafe"))
        XCTAssertTrue("über".matches("UBER"))
        XCTAssertTrue("Gärten".matches("garten"))
    }

    func testNonMatch() {
        XCTAssertFalse("hangul".matches("xyz"))
        XCTAssertFalse("abc".matches("abcd"))
    }

    func testEmptyTermDoesNotMatch() {
        // Foundation `range(of: "")` liefert `nil` → ein leerer Begriff trifft NICHT.
        // Unkritisch, weil die Aufrufer (WordListView/SearchView) vorher per
        // `trimmed.isEmpty || …matches(trimmed)` kurzschließen: bei leerem Suchfeld
        // bleibt die volle Liste sichtbar, ohne `matches("")` je aufzurufen.
        XCTAssertFalse("irgendwas".matches(""))
    }

    func testKoreanSubstring() {
        XCTAssertTrue("학교에 가다".matches("학교"))
        XCTAssertFalse("학교".matches("가방"))
    }
}
