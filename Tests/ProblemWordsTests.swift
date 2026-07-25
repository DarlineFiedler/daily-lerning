@testable import DailyHangul
import XCTest

/// Prüft die Erkennung von „Problemwörtern" (`Vocab.isProblemWord`): oft falsch
/// beantwortet **und** aktuell schwächelnd, mit Mindestversuchen gegen Ausreißer.
/// Reine Logik – kein ModelContext nötig (siehe [[Vocab]]).
final class ProblemWordsTests: XCTestCase {

    /// Baut ein Wort mit exakt gesetzter Historie (umgeht die Tageslogik von
    /// `registerResult`, um den Zustand punktgenau zu treffen).
    private func vocab(times: Int, wrong: Int, streak: Int) -> Vocab {
        let v = Vocab(word: "단어", meaning: "Wort")
        v.timesPracticed = times
        v.totalWrongCount = wrong
        v.successCounter = streak
        return v
    }

    // MARK: - Prädikat

    /// Wenige Versuche (< Mindestanzahl) trotz hoher Fehlerquote ⇒ kein Problemwort.
    func testTooFewAttemptsIsNotProblem() {
        XCTAssertFalse(vocab(times: 2, wrong: 2, streak: 0).isProblemWord)
    }

    /// Genug Versuche, > 40 % falsch, aktuell falsch ⇒ Problemwort.
    func testHighWrongRateAndCurrentlyFailingIsProblem() {
        XCTAssertTrue(vocab(times: 5, wrong: 3, streak: 0).isProblemWord)
    }

    /// Gleiche Lebenszeit-Fehlerquote, aber aktuell auf Erfolgsserie ⇒ selbstheilend,
    /// kein Problemwort mehr.
    func testRecoveredWordIsNotProblem() {
        XCTAssertFalse(vocab(times: 5, wrong: 3, streak: 2).isProblemWord)
    }

    /// Genug Versuche, aber niedrige Fehlerquote ⇒ kein Problemwort.
    func testLowWrongRateIsNotProblem() {
        XCTAssertFalse(vocab(times: 10, wrong: 2, streak: 0).isProblemWord)
    }

    /// Grenzfall exakt 40 % ⇒ kein Problemwort (Schwelle ist streng „größer als").
    func testExactThresholdIsNotProblem() {
        XCTAssertFalse(vocab(times: 5, wrong: 2, streak: 0).isProblemWord)
    }

    /// Genau an der Mindestversuchsgrenze mit hoher Quote ⇒ Problemwort.
    func testMinimumAttemptsWithHighRateIsProblem() {
        XCTAssertTrue(vocab(times: 3, wrong: 2, streak: 0).isProblemWord)
    }

    // MARK: - Zusammenspiel mit registerResult

    /// Ein frisches Wort, dreimal falsch beantwortet, gilt als Problemwort.
    func testThreeWrongViaRegisterResultBecomesProblem() {
        let v = Vocab(word: "가다", meaning: "gehen")
        for _ in 0 ..< 3 { v.registerResult(correct: false) }
        XCTAssertTrue(v.isProblemWord)
    }

    /// Nach einer richtigen Antwort schwächelt das Wort nicht mehr (`successCounter > 0`)
    /// und verlässt die Problemwörter, obwohl die Lebenszeit-Quote hoch bleibt.
    func testCorrectAnswerRemovesFromProblemWords() {
        let v = Vocab(word: "가다", meaning: "gehen")
        for _ in 0 ..< 3 { v.registerResult(correct: false) }
        v.registerResult(correct: true)
        XCTAssertFalse(v.isProblemWord)
    }

    // MARK: - Zusammenstellung

    /// Der Filter (dasselbe Prädikat wie der Pool von PracticeConfigView) liefert genau
    /// die auffälligen Wörter aus einer gemischten Sammlung.
    func testFilterCollectsOnlyProblemWords() {
        let problem = vocab(times: 5, wrong: 4, streak: 0)
        let recovered = vocab(times: 5, wrong: 4, streak: 3)
        let fresh = vocab(times: 1, wrong: 1, streak: 0)
        let solid = vocab(times: 8, wrong: 1, streak: 4)

        let picked = [problem, recovered, fresh, solid].filter(\.isProblemWord)
        XCTAssertEqual(picked.count, 1)
        XCTAssertTrue(picked.first === problem)
    }
}
