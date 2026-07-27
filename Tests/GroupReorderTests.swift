@testable import DailyHangul
import Foundation
import XCTest

/// Prüft die reine Neuordnungs-Logik hinter dem Gruppen-Drag-&-Drop
/// (`GroupListView.reordered`): das gezogene Element rückt an die Position des
/// Ziel-Elements, ohne Elemente zu verlieren oder zu duplizieren.
final class GroupReorderTests: XCTestCase {

    private func ids(_ count: Int) -> [UUID] {
        (0 ..< count).map { _ in UUID() }
    }

    func testMovingUpwardPlacesBeforeTarget() {
        let items = ids(4) // [0,1,2,3]
        let result = GroupListView.reordered(items, moving: items[3], toPositionOf: items[1])
        XCTAssertEqual(result, [items[0], items[3], items[1], items[2]])
    }

    func testMovingDownwardReinsertsBeforeTarget() {
        let items = ids(4) // [0,1,2,3]
        // Element 0 nach unten auf Element 2 ziehen ⇒ landet unmittelbar vor Element 2.
        let result = GroupListView.reordered(items, moving: items[0], toPositionOf: items[2])
        XCTAssertEqual(result, [items[1], items[0], items[2], items[3]])
    }

    func testMovingOntoItselfIsNoOp() {
        let items = ids(3)
        XCTAssertEqual(GroupListView.reordered(items, moving: items[1], toPositionOf: items[1]), items)
    }

    func testUnknownIDsLeaveOrderUnchanged() {
        let items = ids(3)
        XCTAssertEqual(GroupListView.reordered(items, moving: UUID(), toPositionOf: items[0]), items)
        XCTAssertEqual(GroupListView.reordered(items, moving: items[0], toPositionOf: UUID()), items)
    }

    func testReorderNeverLosesOrDuplicatesElements() {
        let items = ids(20)
        let result = GroupListView.reordered(items, moving: items[17], toPositionOf: items[3])
        XCTAssertEqual(Set(result), Set(items))
        XCTAssertEqual(result.count, items.count)
    }

    /// Das gezogene Element landet vorne, wenn es auf das erste Element gezogen wird –
    /// die neue Reihenfolge liefert direkt die 0…n-`sortOrder`, die `applyReorder` schreibt.
    func testMovingToFrontPlacesFirst() {
        let items = ids(5)
        let result = GroupListView.reordered(items, moving: items[4], toPositionOf: items[0])
        XCTAssertEqual(result.first, items[4])
        XCTAssertEqual(result, [items[4], items[0], items[1], items[2], items[3]])
    }
}
