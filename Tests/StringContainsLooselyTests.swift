@testable import DailyHangul
import XCTest

/// Prüft den gemeinsamen `String.containsLoosely(_:)`-Teilstringvergleich (groß-/klein- und
/// diakritika-unempfindlich) der Wortlisten-/Suche-Filterung.
final class StringContainsLooselyTests: XCTestCase {

    func testCaseInsensitiveSubstring() {
        XCTAssertTrue("Hangul lernen".containsLoosely("LERNEN"))
        XCTAssertTrue("hangul".containsLoosely("ang"))
    }

    func testDiacriticInsensitive() {
        XCTAssertTrue("café".containsLoosely("cafe"))
        XCTAssertTrue("über".containsLoosely("UBER"))
        XCTAssertTrue("Gärten".containsLoosely("garten"))
    }

    func testNonMatch() {
        XCTAssertFalse("hangul".containsLoosely("xyz"))
        XCTAssertFalse("abc".containsLoosely("abcd"))
    }

    func testEmptyTermAlwaysMatches() {
        // Leeres Suchfeld ⇒ nichts ausfiltern; Aufrufer brauchen keinen eigenen `isEmpty`-Check.
        XCTAssertTrue("irgendwas".containsLoosely(""))
        XCTAssertTrue("".containsLoosely(""))
    }

    func testKoreanSubstring() {
        XCTAssertTrue("학교에 가다".containsLoosely("학교"))
        XCTAssertFalse("학교".containsLoosely("가방"))
    }
}
