@testable import DailyHangul
import XCTest

final class VocabStatusCountsTests: XCTestCase {

    /// Erzeugt eine Vokabel mit dem gewünschten Lernstatus über den manuellen Setter.
    private func vocab(status: LearningStatus) -> Vocab {
        let v = Vocab(word: "가다", meaning: "gehen")
        v.setStatusManually(status)
        return v
    }

    func testEmptySequence() {
        XCTAssertTrue([Vocab]().statusCounts().isEmpty)
    }

    func testMixedStatusesMatchPerStatusFilter() {
        let vocabs = [
            vocab(status: .new), vocab(status: .new),
            vocab(status: .learning),
            vocab(status: .almostLearned), vocab(status: .almostLearned), vocab(status: .almostLearned),
            vocab(status: .learned)
        ]
        let counts = vocabs.statusCounts()

        // Gegen die alte Berechnung (Einzelfilter je Status) prüfen.
        for status in LearningStatus.allCases {
            let expected = vocabs.filter { $0.status == status }.count
            XCTAssertEqual(counts[status] ?? 0, expected, "Zählung für \(status) weicht ab")
        }
        XCTAssertEqual(counts[.new], 2)
        XCTAssertEqual(counts[.learned], 1)
        // Sparse: nicht vorkommende Status fehlen im Dictionary.
        XCTAssertEqual(counts.values.reduce(0, +), vocabs.count)
    }

    func testAllSameStatusIsSingleEntry() {
        let vocabs = (0 ..< 5).map { _ in vocab(status: .learned) }
        let counts = vocabs.statusCounts()
        XCTAssertEqual(counts.count, 1)
        XCTAssertEqual(counts[.learned], 5)
        XCTAssertNil(counts[.new])
    }
}
