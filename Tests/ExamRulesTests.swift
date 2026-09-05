@testable import DailyHangul
import XCTest

/// Prüft die reinen Prüfungs-Regeln (Issue #94): Zeitbudget skaliert mit der Wortzahl,
/// der Prozent-Score wertet unbeantwortete Wörter wie falsch, und die Bestehensgrenze
/// hängt am TOPIK-Niveau.
final class ExamRulesTests: XCTestCase {

    // MARK: - Zeitbudget

    func testDurationScalesWithWordCount() {
        // 10 s je Wort, sobald das Minimum überschritten ist.
        XCTAssertEqual(ExamRules.duration(wordCount: 5), 50)
        XCTAssertEqual(ExamRules.duration(wordCount: 12), 120)
    }

    func testDurationRespectsMinimum() {
        // Sehr kurze Runden bekommen mindestens das Minimum, damit es nicht gehetzt wirkt.
        XCTAssertEqual(ExamRules.duration(wordCount: 1), ExamRules.minimumSeconds)
        XCTAssertEqual(ExamRules.duration(wordCount: 2), ExamRules.minimumSeconds) // 20 > 2*10
    }

    func testEmptyExamHasNoDuration() {
        XCTAssertEqual(ExamRules.duration(wordCount: 0), 0)
        XCTAssertEqual(ExamRules.duration(wordCount: -3), 0)
    }

    // MARK: - Score

    func testScoreIsRoundedPercentage() {
        XCTAssertEqual(ExamRules.score(correct: 5, total: 10), 50)
        XCTAssertEqual(ExamRules.score(correct: 2, total: 3), 67) // 66.6… → 67
        XCTAssertEqual(ExamRules.score(correct: 1, total: 3), 33) // 33.3… → 33
    }

    func testUnansweredWordsCountAsWrong() {
        // Nenner ist die gesamte Wortzahl: nur 4 von 10 richtig (Rest bei Timeout offen).
        XCTAssertEqual(ExamRules.score(correct: 4, total: 10), 40)
    }

    func testScoreClampsAndHandlesEmpty() {
        XCTAssertEqual(ExamRules.score(correct: 0, total: 0), 0)
        XCTAssertEqual(ExamRules.score(correct: -1, total: 10), 0)
        XCTAssertEqual(ExamRules.score(correct: 99, total: 10), 100) // nie über 100
    }

    // MARK: - Bestehensgrenze

    func testPassMarkDependsOnLevel() {
        XCTAssertEqual(ExamRules.passMark(for: .one), 40)
        XCTAssertEqual(ExamRules.passMark(for: .two), 50)
        XCTAssertEqual(ExamRules.passMark(for: nil), 50) // gemischt → strengere Grenze
    }

    func testPassedExactlyOnThreshold() {
        // Genau auf der Grenze gilt als bestanden (>=).
        XCTAssertTrue(ExamRules.passed(correct: 4, total: 10, level: .one)) // 40 % == 40
        XCTAssertTrue(ExamRules.passed(correct: 5, total: 10, level: .two)) // 50 % == 50
    }

    func testFailedBelowThreshold() {
        XCTAssertFalse(ExamRules.passed(correct: 3, total: 10, level: .one)) // 30 % < 40
        XCTAssertFalse(ExamRules.passed(correct: 4, total: 10, level: .two)) // 40 % < 50
        XCTAssertFalse(ExamRules.passed(correct: 4, total: 10, level: nil)) // 40 % < 50
    }
}
