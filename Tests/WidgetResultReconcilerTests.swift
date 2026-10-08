@testable import DailyHangul
import SwiftData
import XCTest

/// Prüft das Einspielen der vom Widget verbuchten Ergebnisse in den Store
/// (`WidgetResultReconciler`): richtige/falsche Antwort wirken wie `Vocab.registerResult`,
/// unbekannte IDs werden ignoriert und der Tap-Zeitpunkt steuert die Pro-Tag-Zählung.
@MainActor
final class WidgetResultReconcilerTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUp() {
        super.setUp()
        container = PersistenceController.makeContainer(inMemory: true)
        context = container.mainContext
        WidgetResultQueue.clear()
    }

    override func tearDown() {
        WidgetResultQueue.clear()
        context = nil
        container = nil
        super.tearDown()
    }

    @discardableResult
    private func insert(_ word: String) -> Vocab {
        let vocab = Vocab(word: word, meaning: "x")
        context.insert(vocab)
        return vocab
    }

    /// Ein „Gewusst"-Ergebnis verbucht wie eine richtige Antwort: Counter +1, geübt, Zeitstempel.
    func testAppliesCorrectResult() {
        let vocab = insert("가다")
        let now = Date(timeIntervalSince1970: 1_000_000)

        let changed = WidgetResultReconciler.apply(
            [PendingWidgetResult(wordID: vocab.id, correct: true, date: now)],
            context: context
        )

        XCTAssertTrue(changed)
        XCTAssertEqual(vocab.successCounter, 1)
        XCTAssertEqual(vocab.timesPracticed, 1)
        XCTAssertEqual(vocab.lastPracticedAt, now)
        XCTAssertFalse(vocab.lastAnswerWasWrong)
    }

    /// Ein „Nochmal"-Ergebnis verbucht wie eine falsche Antwort.
    func testAppliesWrongResult() {
        let vocab = insert("오다")

        let changed = WidgetResultReconciler.apply(
            [PendingWidgetResult(wordID: vocab.id, correct: false, date: .now)],
            context: context
        )

        XCTAssertTrue(changed)
        XCTAssertEqual(vocab.timesPracticed, 1)
        XCTAssertEqual(vocab.totalWrongCount, 1)
        XCTAssertTrue(vocab.lastAnswerWasWrong)
    }

    /// Unbekannte Wort-IDs (z.B. zwischenzeitlich gelöscht) werden übersprungen, nicht gecrasht.
    func testIgnoresUnknownWordID() {
        insert("가다")

        let changed = WidgetResultReconciler.apply(
            [PendingWidgetResult(wordID: UUID(), correct: true, date: .now)],
            context: context
        )

        XCTAssertFalse(changed)
    }

    /// Leere Ergebnisliste ändert nichts.
    func testEmptyResultsNoChange() {
        XCTAssertFalse(WidgetResultReconciler.apply([], context: context))
    }

    /// Der Tap-Zeitpunkt wird an `registerResult(now:)` durchgereicht: zwei richtige Antworten
    /// an VERSCHIEDENEN Kalendertagen zählen zweimal (die Pro-Tag-Idempotenz greift nur bei
    /// gleichem Tag).
    func testDatePassedThroughForPerDayCounting() {
        let vocab = insert("보다")
        let day1 = Date(timeIntervalSince1970: 0)
        let day2 = Date(timeIntervalSince1970: 60 * 60 * 24 * 2)

        WidgetResultReconciler.apply([
            PendingWidgetResult(wordID: vocab.id, correct: true, date: day1),
            PendingWidgetResult(wordID: vocab.id, correct: true, date: day2)
        ], context: context)

        XCTAssertEqual(vocab.successCounter, 2)
    }

    /// `drain` liest die Queue, spielt sie ein und leert sie danach.
    func testDrainAppliesAndClearsQueue() {
        let vocab = insert("하다")
        WidgetResultQueue.append(PendingWidgetResult(wordID: vocab.id, correct: true, date: .now))

        let changed = WidgetResultReconciler.drain(context: context)

        XCTAssertTrue(changed)
        XCTAssertEqual(vocab.successCounter, 1)
        XCTAssertTrue(WidgetResultQueue.load().isEmpty, "Queue muss nach dem Drain leer sein")
    }

    /// Leere Queue → `drain` meldet „nichts verbucht".
    func testDrainEmptyQueue() {
        XCTAssertFalse(WidgetResultReconciler.drain(context: context))
    }
}
