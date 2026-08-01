@testable import DailyHangul
import XCTest

/// Prüft die Normalisierung frei eingegebener Zielwerte (`GoalOptions.normalizedCustom`).
/// Diese reine Logik steckt hinter dem „Eigener Wert…"-Feld der Ziel-Einstellungen.
final class GoalOptionsTests: XCTestCase {
    func testAcceptsPlainNumber() {
        XCTAssertEqual(GoalOptions.normalizedCustom("250"), 250)
    }

    func testZeroTurnsGoalOff() {
        XCTAssertEqual(GoalOptions.normalizedCustom("0"), 0)
    }

    func testClampsToMaxCustom() {
        XCTAssertEqual(GoalOptions.normalizedCustom("10000"), GoalOptions.maxCustom)
        XCTAssertEqual(GoalOptions.normalizedCustom("99999999999999999999"), GoalOptions.maxCustom)
    }

    func testTrimsSurroundingWhitespace() {
        XCTAssertEqual(GoalOptions.normalizedCustom("  42  "), 42)
    }

    func testRejectsNegative() {
        XCTAssertNil(GoalOptions.normalizedCustom("-3"))
    }

    func testRejectsNonNumeric() {
        XCTAssertNil(GoalOptions.normalizedCustom("abc"))
        XCTAssertNil(GoalOptions.normalizedCustom("3.5"))
        XCTAssertNil(GoalOptions.normalizedCustom(""))
        XCTAssertNil(GoalOptions.normalizedCustom("   "))
    }
}
