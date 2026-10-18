@testable import DailyHangul
import SwiftUI
import XCTest

/// Tests für die Layout-Entscheidung der adaptiven StatTile-Reihe (Issue #120):
/// ab Accessibility-Textgrößen wird vertikal gestapelt statt horizontal gequetscht.
final class StatTileRowTests: XCTestCase {

    func testStandardSizesStayHorizontal() {
        for size in [DynamicTypeSize.xSmall, .large, .xxLarge, .xxxLarge] {
            XCTAssertFalse(StatTileRow<EmptyView>.isStacked(size), "\(size) sollte horizontal bleiben")
        }
    }

    func testAccessibilitySizesStack() {
        for size in [DynamicTypeSize.accessibility1, .accessibility2, .accessibility3, .accessibility4, .accessibility5] {
            XCTAssertTrue(StatTileRow<EmptyView>.isStacked(size), "\(size) sollte stapeln")
        }
    }
}
