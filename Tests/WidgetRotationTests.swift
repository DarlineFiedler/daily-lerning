@testable import DailyHangul
import XCTest

final class WidgetRotationTests: XCTestCase {

    /// Über einen vollen Durchlauf (wordCount aufeinanderfolgende Slots) muss jeder
    /// Wort-Index genau einmal vorkommen – alle Wörter kommen dran, keine Wiederholung.
    func testFullCycleCoversEveryWordExactlyOnce() {
        let wordCount = 7
        let seed: UInt64 = 0xABCD_1234
        for cycle in 0 ..< 5 {
            let start = cycle * wordCount
            let indices = (start ..< start + wordCount).map {
                WidgetRotation.wordIndex(forSlot: $0, wordCount: wordCount, seed: seed)
            }
            XCTAssertEqual(Set(indices), Set(0 ..< wordCount),
                           "Zyklus \(cycle) deckt nicht jeden Index genau einmal ab")
        }
    }

    /// Zwei aufeinanderfolgende Durchläufe sollen unterschiedliche Reihenfolgen haben,
    /// damit man sich die Kette nicht merken kann.
    func testConsecutiveCyclesDiffer() {
        let wordCount = 8
        let seed: UInt64 = 42
        let first = (0 ..< wordCount).map { WidgetRotation.wordIndex(forSlot: $0, wordCount: wordCount, seed: seed) }
        let second = (wordCount ..< 2 * wordCount).map { WidgetRotation.wordIndex(forSlot: $0, wordCount: wordCount, seed: seed) }
        XCTAssertNotEqual(first, second, "Zwei Durchläufe haben dieselbe Reihenfolge")
    }

    /// Gleicher Input muss immer denselben Output liefern – das ist der Grund,
    /// warum das Widget beim App-Öffnen nicht mehr zurückspringt.
    func testDeterministic() {
        for slot in [0, 1, 5, 13, 100, 1_000] {
            let a = WidgetRotation.wordIndex(forSlot: slot, wordCount: 5, seed: 99)
            let b = WidgetRotation.wordIndex(forSlot: slot, wordCount: 5, seed: 99)
            XCTAssertEqual(a, b)
        }
    }

    /// Randfälle: 0 und 1 Wort dürfen nicht crashen.
    func testEdgeCounts() {
        XCTAssertEqual(WidgetRotation.wordIndex(forSlot: 3, wordCount: 0, seed: 1), 0)
        XCTAssertEqual(WidgetRotation.wordIndex(forSlot: 3, wordCount: 1, seed: 1), 0)
        XCTAssertTrue(WidgetRotation.seededPermutation(wordCount: 0, seed: 1).isEmpty)
        XCTAssertEqual(WidgetRotation.seededPermutation(wordCount: 1, seed: 1), [0])
    }

    /// Ein anderer Seed soll (für sinnvoll große wordCount) eine andere Reihenfolge geben.
    func testDifferentSeedsDiffer() {
        let wordCount = 10
        let a = WidgetRotation.seededPermutation(wordCount: wordCount, seed: 1)
        let b = WidgetRotation.seededPermutation(wordCount: wordCount, seed: 2)
        XCTAssertNotEqual(a, b)
        XCTAssertEqual(Set(a), Set(0 ..< wordCount))
        XCTAssertEqual(Set(b), Set(0 ..< wordCount))
    }

    /// Die Permutation soll gleichverteilt sein (kein Modulo-Bias): über viele
    /// Seeds gemittelt landet jeder Index etwa gleich oft auf Position 0.
    func testShuffleIsApproximatelyUniform() {
        let wordCount = 5
        let samples = 20_000
        var firstPositionCounts = [Int](repeating: 0, count: wordCount)
        for seed in 0 ..< samples {
            let perm = WidgetRotation.seededPermutation(wordCount: wordCount, seed: UInt64(seed))
            firstPositionCounts[perm[0]] += 1
        }
        let expected = Double(samples) / Double(wordCount)
        for count in firstPositionCounts {
            XCTAssertLessThan(abs(Double(count) - expected) / expected, 0.1,
                              "Verteilung auf Position 0 ist zu ungleichmäßig: \(firstPositionCounts)")
        }
    }
}
