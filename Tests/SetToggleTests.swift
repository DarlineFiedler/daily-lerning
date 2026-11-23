@testable import DailyHangul
import XCTest

/// Prüft die gemeinsame `Set.toggle(_:)`-Extension (vorher byte-identisch lokal in
/// mehreren Auswahl-Views).
final class SetToggleTests: XCTestCase {

    func testInsertsWhenAbsent() {
        var set: Set<Int> = [1, 2]
        set.toggle(3)
        XCTAssertEqual(set, [1, 2, 3])
    }

    func testRemovesWhenPresent() {
        var set: Set<Int> = [1, 2, 3]
        set.toggle(2)
        XCTAssertEqual(set, [1, 3])
    }

    func testTogglingTwiceIsIdentity() {
        var set: Set<String> = ["a"]
        set.toggle("b")
        set.toggle("b")
        XCTAssertEqual(set, ["a"])
    }

    func testTogglesOnEmptySet() {
        var set: Set<Int> = []
        set.toggle(42)
        XCTAssertEqual(set, [42])
        set.toggle(42)
        XCTAssertTrue(set.isEmpty)
    }
}
