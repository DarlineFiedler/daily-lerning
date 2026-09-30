@testable import DailyHangul
import XCTest

final class ReviewScheduleTests: XCTestCase {

    func testIntervalGrowsWithCounter() {
        // Falsch/neu → morgen; danach wachsende Abstände; ab gelernt (≥5) 14 Tage.
        XCTAssertEqual(ReviewSchedule.intervalDays(for: 0), 1)
        XCTAssertEqual(ReviewSchedule.intervalDays(for: 1), 1)
        XCTAssertEqual(ReviewSchedule.intervalDays(for: 2), 2)
        XCTAssertEqual(ReviewSchedule.intervalDays(for: 3), 4)
        XCTAssertEqual(ReviewSchedule.intervalDays(for: 4), 7)
        XCTAssertEqual(ReviewSchedule.intervalDays(for: 5), 14)
        XCTAssertEqual(ReviewSchedule.intervalDays(for: 42), 14)
    }

    func testIntervalIsMonotonic() {
        let days = (0 ... 6).map { ReviewSchedule.intervalDays(for: $0) }
        XCTAssertEqual(days, days.sorted())
    }

    func testNextReviewDateMatchesInterval() {
        let base = Date(timeIntervalSince1970: 1_000_000)
        let next = ReviewSchedule.nextReviewDate(for: 3, from: base)
        let expected = Calendar.current.date(byAdding: .day, value: 4, to: base)!
        XCTAssertEqual(next, expected)
    }

    // MARK: - Vocab.isDue

    func testNewVocabIsDueImmediately() {
        let vocab = Vocab(word: "가다", meaning: "gehen")
        XCTAssertNil(vocab.nextReviewAt)
        XCTAssertTrue(vocab.isDue())
    }

    func testRegisterResultSchedulesFutureReview() {
        let vocab = Vocab(word: "가다", meaning: "gehen")
        vocab.registerResult(correct: true) // counter 1 → +1 Tag
        XCTAssertNotNil(vocab.nextReviewAt)
        XCTAssertFalse(vocab.isDue()) // erst morgen wieder fällig
        XCTAssertTrue(vocab.isDue(asOf: .now.addingTimeInterval(2 * 86_400)))
    }

    func testLapsedLearnedWordEntersRelearningInterval() {
        let vocab = Vocab(word: "가다", meaning: "gehen")
        // Counter steigt nur einmal pro Tag → an fünf aufeinanderfolgenden Tagen bis „gelernt".
        for day in 0 ..< 5 { vocab.registerResult(correct: true, now: day.daysFromNow) }
        XCTAssertEqual(vocab.successCounter, 5)
        // Ein einzelner Fehler senkt den Counter nur eine Stufe (Issue #118): 5 → 3 (fast gelernt).
        // Die nächste Fälligkeit folgt dem Relearning-Intervall (4 Tage), nicht „morgen" und
        // auch nicht dem 14-Tage-Intervall eines gelernten Worts.
        vocab.registerResult(correct: false, now: 5.daysFromNow)
        XCTAssertEqual(vocab.successCounter, LearningStatus.almostLearnedThreshold)
        XCTAssertFalse(vocab.isDue(asOf: 6.daysFromNow)) // nicht schon morgen fällig
        XCTAssertTrue(vocab.isDue(asOf: 9.daysFromNow)) // aber deutlich früher als in 14 Tagen
    }

    func testManualNewClearsSchedule() {
        let vocab = Vocab(word: "가다", meaning: "gehen")
        vocab.registerResult(correct: true)
        vocab.setStatusManually(.new)
        XCTAssertNil(vocab.nextReviewAt)
        XCTAssertTrue(vocab.isDue())
    }
}
