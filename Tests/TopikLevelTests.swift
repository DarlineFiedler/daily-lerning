@testable import DailyHangul
import XCTest

/// Prüft das Parsen der TOPIK-Einstufung aus einem CSV-Feld (`TopikLevel(csv:)`) –
/// römische Kurzform, offizielle Level-Zahlen und ungültige/leere Werte.
final class TopikLevelTests: XCTestCase {

    func testParsesRomanShortForms() {
        XCTAssertEqual(TopikLevel(csv: "I"), .one)
        XCTAssertEqual(TopikLevel(csv: "ii"), .two)
        XCTAssertEqual(TopikLevel(csv: "  II  "), .two)
        XCTAssertEqual(TopikLevel(csv: "TOPIK I"), .one)
        XCTAssertEqual(TopikLevel(csv: "topik ii"), .two)
    }

    func testMapsNumericLevelsToBands() {
        XCTAssertEqual(TopikLevel(csv: "1"), .one)
        XCTAssertEqual(TopikLevel(csv: "2"), .one)
        XCTAssertEqual(TopikLevel(csv: "3"), .two)
        XCTAssertEqual(TopikLevel(csv: "6"), .two)
    }

    func testReturnsNilForInvalidOrEmpty() {
        XCTAssertNil(TopikLevel(csv: ""))
        XCTAssertNil(TopikLevel(csv: "   "))
        XCTAssertNil(TopikLevel(csv: "III"))
        XCTAssertNil(TopikLevel(csv: "0"))
        XCTAssertNil(TopikLevel(csv: "7"))
        XCTAssertNil(TopikLevel(csv: "Anfänger"))
    }

    func testAbbreviationAndTitleKey() {
        XCTAssertEqual(TopikLevel.one.abbreviation, "I")
        XCTAssertEqual(TopikLevel.two.abbreviation, "II")
        XCTAssertEqual(TopikLevel.one.titleKey, "topik.i")
        XCTAssertEqual(TopikLevel.two.titleKey, "topik.ii")
    }

    /// Anzeigetitel für die Prüfungs-Ansicht (`Optional<TopikLevel>.examTitle`): konkrete
    /// Stufe → lokalisierter Name, keine Stufe → generisches „TOPIK".
    func testExamTitle() {
        let one: TopikLevel? = .one
        let two: TopikLevel? = .two
        let noLevel: TopikLevel? = nil
        XCTAssertEqual(one.examTitle, L("topik.i"))
        XCTAssertEqual(two.examTitle, L("topik.ii"))
        XCTAssertEqual(noLevel.examTitle, "TOPIK")
        // Eine gewählte Stufe darf nie auf den generischen Fallback zurückfallen.
        XCTAssertNotEqual(one.examTitle, "TOPIK")
    }
}
