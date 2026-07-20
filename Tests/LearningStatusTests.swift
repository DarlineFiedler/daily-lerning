@testable import DailyHangul
import XCTest

final class LearningStatusTests: XCTestCase {

    func testNotPracticedIsNew() {
        XCTAssertEqual(LearningStatus.computed(counter: 0, practiced: false), .new)
        XCTAssertEqual(LearningStatus.computed(counter: 99, practiced: false), .new)
    }

    func testThresholds() {
        XCTAssertEqual(LearningStatus.computed(counter: 0, practiced: true), .learning)
        XCTAssertEqual(LearningStatus.computed(counter: LearningStatus.almostLearnedThreshold - 1, practiced: true), .learning)
        XCTAssertEqual(LearningStatus.computed(counter: LearningStatus.almostLearnedThreshold, practiced: true), .almostLearned)
        XCTAssertEqual(LearningStatus.computed(counter: LearningStatus.masteredThreshold - 1, practiced: true), .almostLearned)
        XCTAssertEqual(LearningStatus.computed(counter: LearningStatus.masteredThreshold, practiced: true), .learned)
        XCTAssertEqual(LearningStatus.computed(counter: LearningStatus.masteredThreshold + 5, practiced: true), .learned)
    }

    // MARK: - Vocab-Ergebnisverbuchung

    func testRegisterResultCorrectRaisesStatus() {
        let vocab = Vocab(word: "가다", meaning: "gehen")
        for _ in 0 ..< LearningStatus.masteredThreshold {
            vocab.registerResult(correct: true)
        }
        XCTAssertEqual(vocab.status, .learned)
        XCTAssertEqual(vocab.successCounter, LearningStatus.masteredThreshold)
        XCTAssertEqual(vocab.timesPracticed, LearningStatus.masteredThreshold)
    }

    func testRegisterResultWrongResetsCounter() {
        let vocab = Vocab(word: "가다", meaning: "gehen")
        vocab.registerResult(correct: true)
        vocab.registerResult(correct: true)
        vocab.registerResult(correct: false)
        XCTAssertEqual(vocab.successCounter, 0)
        XCTAssertEqual(vocab.status, .learning) // geübt, aber Counter zurückgesetzt
        XCTAssertEqual(vocab.timesPracticed, 3)
    }

    func testManualStatusAlignsCounter() {
        let vocab = Vocab(word: "가다", meaning: "gehen")
        vocab.setStatusManually(.almostLearned)
        XCTAssertEqual(vocab.status, .almostLearned)
        // Nach dem manuellen Setzen soll eine richtige Antwort sinnvoll fortsetzen.
        vocab.registerResult(correct: true)
        XCTAssertEqual(vocab.successCounter, LearningStatus.almostLearnedThreshold + 1)
    }

    func testManualNewResets() {
        let vocab = Vocab(word: "가다", meaning: "gehen")
        vocab.registerResult(correct: true)
        vocab.setStatusManually(.new)
        XCTAssertEqual(vocab.status, .new)
        XCTAssertEqual(vocab.successCounter, 0)
        XCTAssertEqual(vocab.timesPracticed, 0)
        XCTAssertFalse(vocab.hasBeenPracticed)
    }
}
