@testable import DailyHangul
import XCTest

final class WordOfDayTests: XCTestCase {

    /// Erzeugt ein Wort mit gesetztem Status.
    private func word(_ status: LearningStatus, _ text: String = "가") -> Vocab {
        let vocab = Vocab(word: text, meaning: "a")
        if status != .new { vocab.setStatusManually(status) }
        return vocab
    }

    func testPrefersLearningStatusOverNew() {
        let newWord = word(.new, "새")
        let learningWord = word(.learning, "배")
        // Über mehrere Tage prüfen, damit der Tages-Modulo das neue Wort nie treffen darf.
        for offset in 0 ..< 7 {
            let picked = WordOfDay.pick(from: [newWord, learningWord], now: offset.daysFromNow)
            XCTAssertEqual(picked?.id, learningWord.id)
        }
    }

    func testFallsBackToAllWhenOnlyNewWords() {
        let picked = WordOfDay.pick(from: [word(.new), word(.new)], now: 0.daysFromNow)
        XCTAssertNotNil(picked)
    }

    func testReturnsNilWhenEmpty() {
        XCTAssertNil(WordOfDay.pick(from: [], now: 0.daysFromNow))
    }

    func testStableWithinSameDay() {
        let words = [word(.learning, "가"), word(.almostLearned, "나"), word(.learned, "다")]
        let first = WordOfDay.pick(from: words, now: 3.daysFromNow)
        let second = WordOfDay.pick(from: words, now: 3.daysFromNow)
        XCTAssertEqual(first?.id, second?.id)
    }

    func testLearnedCountsAsCandidate() {
        let learnedWord = word(.learned)
        XCTAssertEqual(WordOfDay.pick(from: [learnedWord], now: 0.daysFromNow)?.id, learnedWord.id)
    }
}
