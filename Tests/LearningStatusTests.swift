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
        // Der Counter steigt nur einmal pro Tag → über mehrere Tage bis „Gelernt".
        for day in 0 ..< LearningStatus.masteredThreshold {
            vocab.registerResult(correct: true, now: day.daysFromNow)
        }
        XCTAssertEqual(vocab.status, .learned)
        XCTAssertEqual(vocab.successCounter, LearningStatus.masteredThreshold)
        XCTAssertEqual(vocab.timesPracticed, LearningStatus.masteredThreshold)
    }

    // MARK: - „Nur +1 pro Tag"

    func testMultipleCorrectSameDayCountOnce() {
        let vocab = Vocab(word: "가다", meaning: "gehen")
        let today = Date.now
        vocab.registerResult(correct: true, now: today)
        vocab.registerResult(correct: true, now: today)
        vocab.registerResult(correct: true, now: today)
        XCTAssertEqual(vocab.successCounter, 1) // weitere richtige Antworten zählen nicht
        XCTAssertEqual(vocab.timesPracticed, 3) // aber jede Bearbeitung wird gezählt
    }

    func testCorrectOnDifferentDaysCounts() {
        let vocab = Vocab(word: "가다", meaning: "gehen")
        vocab.registerResult(correct: true, now: 0.daysFromNow)
        vocab.registerResult(correct: true, now: 1.daysFromNow)
        XCTAssertEqual(vocab.successCounter, 2)
    }

    func testLearnedWordWrongDropsToLearning() {
        let vocab = Vocab(word: "가다", meaning: "gehen")
        for day in 0 ..< LearningStatus.masteredThreshold {
            vocab.registerResult(correct: true, now: day.daysFromNow)
        }
        XCTAssertEqual(vocab.status, .learned)
        // Ein versehentlich falsch beantwortetes „Gelernt"-Wort fällt zurück.
        vocab.registerResult(correct: false, now: LearningStatus.masteredThreshold.daysFromNow)
        XCTAssertEqual(vocab.successCounter, 0)
        XCTAssertEqual(vocab.status, .learning)
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

    // Semantik hinter dem Mehrfach-/Kontextmenü-„Status setzen": jeder Fall aus
    // `LearningStatus.allCases` (wie im Menü angeboten) setzt Status + Counter korrekt
    // und plant – außer bei „Neu" – eine Wiederholung ein.
    func testManualStatusForAllCasesAlignsCounterAndSchedule() {
        let expectedCounter: [LearningStatus: Int] = [
            .new: 0,
            .learning: LearningStatus.learningThreshold,
            .almostLearned: LearningStatus.almostLearnedThreshold,
            .learned: LearningStatus.masteredThreshold
        ]
        for status in LearningStatus.allCases {
            let vocab = Vocab(word: "가다", meaning: "gehen")
            vocab.setStatusManually(status)
            XCTAssertEqual(vocab.status, status)
            XCTAssertEqual(vocab.successCounter, expectedCounter[status])
            if status == .new {
                XCTAssertNil(vocab.nextReviewAt) // „Neu" → sofort fällig, kein Plan
            } else {
                XCTAssertNotNil(vocab.nextReviewAt) // sonst eingeplant
            }
        }
    }

    // Semantik hinter dem Gruppen-/Mehrfach-Reset: „Neu" löscht auch den Wiederholungsplan.
    func testManualNewClearsSchedule() {
        let vocab = Vocab(word: "가다", meaning: "gehen")
        vocab.setStatusManually(.learned)
        XCTAssertNotNil(vocab.nextReviewAt) // Gelernt → eingeplant
        vocab.setStatusManually(.new)
        XCTAssertEqual(vocab.status, .new)
        XCTAssertEqual(vocab.successCounter, 0)
        XCTAssertNil(vocab.nextReviewAt) // Reset macht das Wort sofort fällig
    }
}
