@testable import DailyHangul
import XCTest

final class DailyPlanTests: XCTestCase {

    /// Erzeugt ein Wort mit gesetztem Status; optional als „heute bereits bearbeitet".
    private func word(_ status: LearningStatus, handledToday: Bool = false) -> Vocab {
        let vocab = Vocab(word: "가", meaning: "a")
        if status != .new { vocab.setStatusManually(status) }
        vocab.lastPracticedAt = handledToday ? .now : nil
        return vocab
    }

    func testLearnTierWhenLearningWordsAreOpen() {
        let result = DailyPlan.today(from: [word(.learning), word(.learned)])
        XCTAssertEqual(result.kind, .learn)
        XCTAssertEqual(result.words.count, 1)
    }

    func testAlmostLearnedCountsAsLearnTier() {
        let result = DailyPlan.today(from: [word(.almostLearned)])
        XCTAssertEqual(result.kind, .learn)
    }

    func testReviewFallbackWhenOnlyLearnedOpen() {
        // Lern-Wort ist heute schon erledigt → fällt auf „wiederholen" (gelernte Wörter) zurück.
        let result = DailyPlan.today(from: [word(.learning, handledToday: true), word(.learned)])
        XCTAssertEqual(result.kind, .review)
        XCTAssertEqual(result.words.count, 1)
    }

    func testDoneWhenEverythingHandledToday() {
        let result = DailyPlan.today(from: [
            word(.learning, handledToday: true),
            word(.learned, handledToday: true)
        ])
        XCTAssertEqual(result.kind, .done)
        XCTAssertTrue(result.words.isEmpty)
    }

    func testNoneWhenOnlyNewWords() {
        let result = DailyPlan.today(from: [word(.new), word(.new)])
        XCTAssertEqual(result.kind, .none)
    }

    func testNoneWhenEmpty() {
        XCTAssertEqual(DailyPlan.today(from: []).kind, .none)
    }

    func testHandledTodayDropsFromOpenList() {
        let open = word(.learning)
        let result = DailyPlan.today(from: [word(.learning, handledToday: true), open])
        XCTAssertEqual(result.kind, .learn)
        XCTAssertEqual(result.words.map(\.id), [open.id])
    }
}
