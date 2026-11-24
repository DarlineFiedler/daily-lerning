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

    // MARK: - progressCounts()

    /// Vokabel mit Status und optional einer Historie, die `isProblemWord` erfüllt
    /// (5 Versuche, 3 falsch, letzte Antwort falsch). Die Historie wird **nach**
    /// `setStatusManually` gesetzt, weil `.new` die Zähler zurücksetzt.
    private func vocab(status: LearningStatus, problem: Bool) -> Vocab {
        let v = vocab(status: status)
        if problem {
            v.timesPracticed = 5
            v.totalWrongCount = 3
            v.lastAnswerWasWrong = true
        }
        return v
    }

    func testProgressCountsEmpty() {
        let counts = [Vocab]().progressCounts()
        XCTAssertTrue(counts.status.isEmpty)
        XCTAssertEqual(counts.problems, 0)
    }

    func testProgressCountsCountsProblemWords() {
        let vocabs = [
            vocab(status: .new, problem: false),
            vocab(status: .learning, problem: true),
            vocab(status: .learning, problem: false),
            vocab(status: .almostLearned, problem: true),
            vocab(status: .learned, problem: true),
            vocab(status: .learned, problem: false)
        ]
        let counts = vocabs.progressCounts()

        XCTAssertEqual(counts.problems, 3)
        XCTAssertEqual(counts.problems, vocabs.filter(\.isProblemWord).count)
        for status in LearningStatus.allCases {
            let expected = vocabs.filter { $0.status == status }.count
            XCTAssertEqual(counts.status[status] ?? 0, expected, "Zählung für \(status) weicht ab")
        }
        XCTAssertEqual(counts.status.values.reduce(0, +), vocabs.count)
    }

    /// Hohe Fehlerquote, aber letzte Antwort richtig ⇒ zählt nicht als Problemwort.
    func testProgressCountsSkipsRecoveredWord() {
        let recovered = vocab(status: .learning, problem: true)
        recovered.lastAnswerWasWrong = false
        let counts = [recovered, vocab(status: .new, problem: false)].progressCounts()
        XCTAssertEqual(counts.problems, 0)
        XCTAssertEqual(counts.status.values.reduce(0, +), 2)
    }

    func testProgressCountsStatusMatchesStatusCounts() {
        let vocabs = [
            vocab(status: .new, problem: false), vocab(status: .new, problem: false),
            vocab(status: .learning, problem: true),
            vocab(status: .almostLearned, problem: true),
            vocab(status: .learned, problem: false)
        ]
        XCTAssertEqual(vocabs.progressCounts().status, vocabs.statusCounts())
    }

    func testAllSameStatusIsSingleEntry() {
        let vocabs = (0 ..< 5).map { _ in vocab(status: .learned) }
        let counts = vocabs.statusCounts()
        XCTAssertEqual(counts.count, 1)
        XCTAssertEqual(counts[.learned], 5)
        XCTAssertNil(counts[.new])
    }
}
