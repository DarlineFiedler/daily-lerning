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
        resetStores()
    }

    override func tearDown() {
        WidgetResultQueue.clear()
        resetStores()
        context = nil
        container = nil
        super.tearDown()
    }

    /// Setzt die vom Reconciler beschriebenen, prozess-geteilten Stores zurück
    /// (Streak + Wochen-Log in `AppGroup.defaults`), damit Tests isoliert laufen.
    private func resetStores() {
        let d = AppGroup.defaults
        for key in [StreakKeys.current, StreakKeys.longest, StreakKeys.lastActiveDay,
                    StreakKeys.jokers, StreakKeys.weekAnchor, StreakKeys.jokerUses,
                    StreakKeys.activeDays, WeeklyReviewKeys.log] {
            d.removeObject(forKey: key)
        }
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

    /// Ein Widget-Ergebnis zählt für die Tages-Streak (sonst reißt sie trotz Aktivität ab).
    func testWidgetResultRegistersStreak() {
        let vocab = insert("먹다")
        let today = Date()

        WidgetResultReconciler.apply(
            [PendingWidgetResult(wordID: vocab.id, correct: true, date: today)],
            context: context
        )

        XCTAssertEqual(StreakStore.displayStreak(asOf: today), 1,
                       "Ein Widget-Tipp muss den heutigen Tag für die Streak zählen.")
    }

    /// Ein Widget-Ergebnis füttert den Wochenrückblick (distinct geübtes Wort + Trefferquote),
    /// damit Ziel-/Statistik-Zahlen nicht gegenüber dem Wortstatus driften.
    func testWidgetResultFeedsWeeklyActivity() {
        let vocab = insert("자다")
        let today = Date()

        WeeklyReviewStore.saveActivity(WeeklyActivity())
        WidgetResultReconciler.apply(
            [PendingWidgetResult(wordID: vocab.id, correct: true, date: today)],
            context: context
        )

        XCTAssertEqual(WeeklyReviewStore.dayProgress(for: .practiced, asOf: today), 1)
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

    /// Enthält die Queue nur unbekannte (z.B. gelöschte) IDs, wird sie trotzdem geleert –
    /// solche Einträge dürfen nicht endlos auflaufen.
    func testDrainClearsQueueWithOnlyUnknownIDs() {
        WidgetResultQueue.append(PendingWidgetResult(wordID: UUID(), correct: true, date: .now))

        let changed = WidgetResultReconciler.drain(context: context)

        XCTAssertFalse(changed, "Unbekannte IDs verbuchen nichts.")
        XCTAssertTrue(WidgetResultQueue.load().isEmpty, "Unbekannte IDs müssen aus der Queue fallen.")
    }
}
