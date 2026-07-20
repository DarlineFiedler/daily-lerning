@testable import DailyHangul
import XCTest

final class AnswerCheckerTests: XCTestCase {

    func testExactMatch() {
        XCTAssertTrue(AnswerChecker.isCorrect(typed: "gehen", expected: "gehen"))
    }

    func testTrimmedAndCaseInsensitive() {
        XCTAssertTrue(AnswerChecker.isCorrect(typed: "  Gehen ", expected: "gehen"))
    }

    func testDiacriticInsensitive() {
        XCTAssertTrue(AnswerChecker.isCorrect(typed: "uben", expected: "üben"))
    }

    func testExpectedVariantsMatch() {
        // Erwartete Antwort bietet mehrere Varianten – eine davon reicht.
        XCTAssertTrue(AnswerChecker.isCorrect(typed: "schauen", expected: "sehen / schauen"))
        XCTAssertTrue(AnswerChecker.isCorrect(typed: "sehen", expected: "sehen, schauen"))
    }

    func testTypedVariantsMatch() {
        // Eingabe mit mehreren Varianten matcht, wenn eine zur erwarteten passt.
        XCTAssertTrue(AnswerChecker.isCorrect(typed: "gehen, laufen", expected: "gehen"))
    }

    func testWrongAnswer() {
        XCTAssertFalse(AnswerChecker.isCorrect(typed: "essen", expected: "gehen"))
    }

    func testEmptyTypedIsNeverCorrect() {
        XCTAssertFalse(AnswerChecker.isCorrect(typed: "", expected: "gehen"))
        XCTAssertFalse(AnswerChecker.isCorrect(typed: "   ", expected: "gehen"))
        // Auch bei leerer erwarteter Antwort darf leere Eingabe nicht „richtig“ sein.
        XCTAssertFalse(AnswerChecker.isCorrect(typed: "", expected: ""))
    }
}
