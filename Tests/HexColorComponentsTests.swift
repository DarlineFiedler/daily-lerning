@testable import DailyHangul
import XCTest

/// Tests für den gemeinsamen Hex-Parser (eine Quelle der Wahrheit für `Color(hex:)`
/// und die abgeleitete Garten-Blütenoptik).
final class HexColorComponentsTests: XCTestCase {

    func testParsesSixDigitHex() {
        let c = HexColorComponents.parse("#EF4444")
        XCTAssertEqual(c?.red, 0xEF / 255, accuracy: 0.0001)
        XCTAssertEqual(c?.green, 0x44 / 255, accuracy: 0.0001)
        XCTAssertEqual(c?.blue, 0x44 / 255, accuracy: 0.0001)
        XCTAssertEqual(c?.alpha, 1)
    }

    func testParsesSixDigitWithoutHash() {
        XCTAssertEqual(HexColorComponents.parse("22C55E"), HexColorComponents.parse("#22C55E"))
    }

    func testParsesEightDigitHexAsRGBA() {
        // RRGGBBAA – halbtransparentes Weiß.
        let c = HexColorComponents.parse("#FFFFFF80")
        XCTAssertEqual(c?.red, 1)
        XCTAssertEqual(c?.green, 1)
        XCTAssertEqual(c?.blue, 1)
        XCTAssertEqual(c?.alpha ?? 0, 0x80 / 255, accuracy: 0.0001)
    }

    func testReturnsNilForUnparsable() {
        XCTAssertNil(HexColorComponents.parse("not-a-color"))
        XCTAssertNil(HexColorComponents.parse(""))
        XCTAssertNil(HexColorComponents.parse("#FFF")) // 3-stellig wird nicht unterstützt
    }
}
