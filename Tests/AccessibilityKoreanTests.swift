@testable import DailyHangul
import SwiftUI
import XCTest

/// Tests für die VoiceOver-Helfer der Lern-Modi (Issue #120): koreanischer
/// Sprachkontext und der abgeleitete Status einer Antwortoption.
final class AccessibilityKoreanTests: XCTestCase {

    func testKoreanTagsLanguageAndKeepsText() {
        let attributed = AttributedString.korean("안녕")
        XCTAssertEqual(attributed.languageIdentifier, "ko-KR")
        XCTAssertEqual(String(attributed.characters), "안녕")
    }

    func testOptionStateUnansweredBeforeAnswer() {
        XCTAssertEqual(
            ChoiceOptionState.resolve(answered: false, isRight: true, isChosen: true),
            .unanswered
        )
    }

    func testOptionStateCorrectWinsOverChosen() {
        // Die richtige Lösung bleibt „correct", auch wenn sie selbst gewählt wurde.
        XCTAssertEqual(
            ChoiceOptionState.resolve(answered: true, isRight: true, isChosen: true),
            .correct
        )
    }

    func testOptionStateChosenWrong() {
        XCTAssertEqual(
            ChoiceOptionState.resolve(answered: true, isRight: false, isChosen: true),
            .chosenWrong
        )
    }

    func testOptionStateOtherAfterAnswer() {
        XCTAssertEqual(
            ChoiceOptionState.resolve(answered: true, isRight: false, isChosen: false),
            .other
        )
    }
}
