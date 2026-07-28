@testable import DailyHangul
import XCTest

/// Prüft die reine Fortschrittsberechnung der Live-Activity-`ContentState`
/// (ohne ActivityKit-API selbst).
final class PracticeActivityStateTests: XCTestCase {
    func testProgressIsZeroWhenTotalZero() {
        let state = PracticeActivityAttributes.ContentState(total: 0, position: 0, correct: 0, wrong: 0)
        XCTAssertEqual(state.progress, 0)
    }

    func testProgressHalfway() {
        let state = PracticeActivityAttributes.ContentState(total: 10, position: 5, correct: 4, wrong: 1)
        XCTAssertEqual(state.progress, 0.5, accuracy: 0.0001)
    }

    func testProgressClampedToOne() {
        let state = PracticeActivityAttributes.ContentState(total: 4, position: 6, correct: 6, wrong: 0)
        XCTAssertEqual(state.progress, 1)
    }
}
