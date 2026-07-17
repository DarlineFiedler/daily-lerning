import XCTest
@testable import DailyHangul

final class WidgetRotationTests: XCTestCase {

    /// Über einen vollen Durchlauf (count aufeinanderfolgende Slots) muss jeder
    /// Wort-Index genau einmal vorkommen – alle Wörter kommen dran, keine Wiederholung.
    func testFullCycleCoversEveryWordExactlyOnce() {
        let count = 7
        let seed: UInt64 = 0xABCD_1234
        for cycle in 0..<5 {
            let start = cycle * count
            let indices = (start..<start + count).map {
                WidgetRotation.wordIndex(forSlot: $0, count: count, seed: seed)
            }
            XCTAssertEqual(Set(indices), Set(0..<count),
                           "Zyklus \(cycle) deckt nicht jeden Index genau einmal ab")
        }
    }

    /// Zwei aufeinanderfolgende Durchläufe sollen unterschiedliche Reihenfolgen haben,
    /// damit man sich die Kette nicht merken kann.
    func testConsecutiveCyclesDiffer() {
        let count = 8
        let seed: UInt64 = 42
        let first = (0..<count).map { WidgetRotation.wordIndex(forSlot: $0, count: count, seed: seed) }
        let second = (count..<2 * count).map { WidgetRotation.wordIndex(forSlot: $0, count: count, seed: seed) }
        XCTAssertNotEqual(first, second, "Zwei Durchläufe haben dieselbe Reihenfolge")
    }

    /// Gleicher Input muss immer denselben Output liefern – das ist der Grund,
    /// warum das Widget beim App-Öffnen nicht mehr zurückspringt.
    func testDeterministic() {
        for slot in [0, 1, 5, 13, 100, 1_000] {
            let a = WidgetRotation.wordIndex(forSlot: slot, count: 5, seed: 99)
            let b = WidgetRotation.wordIndex(forSlot: slot, count: 5, seed: 99)
            XCTAssertEqual(a, b)
        }
    }

    /// Randfälle: 0 und 1 Wort dürfen nicht crashen.
    func testEdgeCounts() {
        XCTAssertEqual(WidgetRotation.wordIndex(forSlot: 3, count: 0, seed: 1), 0)
        XCTAssertEqual(WidgetRotation.wordIndex(forSlot: 3, count: 1, seed: 1), 0)
        XCTAssertTrue(WidgetRotation.seededPermutation(count: 0, seed: 1).isEmpty)
        XCTAssertEqual(WidgetRotation.seededPermutation(count: 1, seed: 1), [0])
    }

    /// Ein anderer Seed soll (für sinnvoll große count) eine andere Reihenfolge geben.
    func testDifferentSeedsDiffer() {
        let count = 10
        let a = WidgetRotation.seededPermutation(count: count, seed: 1)
        let b = WidgetRotation.seededPermutation(count: count, seed: 2)
        XCTAssertNotEqual(a, b)
        XCTAssertEqual(Set(a), Set(0..<count))
        XCTAssertEqual(Set(b), Set(0..<count))
    }
}
