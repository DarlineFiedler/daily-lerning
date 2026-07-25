@testable import DailyHangul
import XCTest

/// Prüft `DailyPlan.openWordCount` – die Grundlage für die App-Icon-Badge-Zahl.
/// Tagesbasiert: zählt heute noch offene Lern- + Wiederhol-Wörter, neue ausgenommen.
final class BadgeCountTests: XCTestCase {

    /// Erzeugt ein Wort mit gesetztem Status; optional als „heute bereits bearbeitet".
    private func word(_ status: LearningStatus, handledToday: Bool = false) -> Vocab {
        let vocab = Vocab(word: "가", meaning: "a")
        if status != .new { vocab.setStatusManually(status) }
        vocab.lastPracticedAt = handledToday ? .now : nil
        return vocab
    }

    func testEmptyIsZero() {
        XCTAssertEqual(DailyPlan.openWordCount(from: []), 0)
    }

    func testNewWordsAreExcluded() {
        XCTAssertEqual(DailyPlan.openWordCount(from: [word(.new), word(.new)]), 0)
    }

    func testSumsOpenLearnAndReviewTiers() {
        let count = DailyPlan.openWordCount(from: [
            word(.learning),
            word(.almostLearned),
            word(.learned)
        ])
        XCTAssertEqual(count, 3)
    }

    func testHandledTodayWordsAreExcluded() {
        let count = DailyPlan.openWordCount(from: [
            word(.learning, handledToday: true),
            word(.learning),
            word(.learned, handledToday: true),
            word(.learned)
        ])
        XCTAssertEqual(count, 2)
    }

    func testZeroWhenEverythingHandledToday() {
        let count = DailyPlan.openWordCount(from: [
            word(.learning, handledToday: true),
            word(.learned, handledToday: true)
        ])
        XCTAssertEqual(count, 0)
    }
}
