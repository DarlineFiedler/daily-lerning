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

    // MARK: - renumberedOrder (Reaktivieren)

    /// Nach dem Drag & Drop stehen aktive Gruppen auf 0…n; eine archivierte Gruppe
    /// behält ihren alten `sortOrder` (hier 1) und würde beim Reaktivieren mit einem
    /// aktiven Wert kollidieren. `renumberedOrder` verteilt neue, eindeutige Indizes
    /// und schiebt die reaktivierte Gruppe ans Ende.
    func testReactivationRenumbersWithoutCollision() {
        let a = UUID(), b = UUID(), reactivated = UUID(), c = UUID()
        // Aktive: 0,1,2 (a,b,c); reaktivierte Gruppe kommt mit altem, kollidierendem sortOrder 1.
        let pairs: [(id: UUID, sortOrder: Int)] = [
            (a, 0), (b, 1), (c, 2), (reactivated, 1)
        ]
        let order = GroupListView.renumberedOrder(pairs, bringingToEnd: reactivated)

        XCTAssertEqual(order, [a, b, c, reactivated])
        // Die Index-Positionen (= neue sortOrder) sind lückenlos und eindeutig.
        XCTAssertEqual(Array(order.indices), [0, 1, 2, 3])
    }

    /// Ohne `bringingToEnd` bleibt die reine Reihenfolge nach `sortOrder` erhalten.
    func testRenumberedOrderSortsByExistingOrder() {
        let a = UUID(), b = UUID(), c = UUID()
        let pairs: [(id: UUID, sortOrder: Int)] = [(c, 5), (a, 0), (b, 2)]
        XCTAssertEqual(GroupListView.renumberedOrder(pairs, bringingToEnd: nil), [a, b, c])
    }
}
