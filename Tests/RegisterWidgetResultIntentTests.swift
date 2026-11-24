@testable import DailyHangul
import SwiftData
import XCTest

/// Prüft den Einstieg der „Gewusst"/„Nochmal"-Buttons im Wort-Widget
/// (`RegisterWidgetResultIntent`): `perform()` legt das Ergebnis in die
/// `WidgetResultQueue`, und der `WidgetResultReconciler` übernimmt es danach ins
/// Vokabel-Modell. Abgedeckt sind auch die Randfälle ungültige/unbekannte ID und doppelter
/// Tap. In Tests zeigt `AppGroup.containerURL` mangels echter App-Group auf das temporäre
/// Verzeichnis – deshalb Queue und geteilte Defaults vor/nach jedem Test leeren.
@MainActor
final class RegisterWidgetResultIntentTests: XCTestCase {

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

    private func insert(_ word: String) -> Vocab {
        let vocab = Vocab(word: word, meaning: "x")
        context.insert(vocab)
        return vocab
    }

    // MARK: - perform() → Queue

    /// „Gewusst" legt genau einen Eintrag mit ID, `correct == true` und Tap-Zeitpunkt ab.
    func testPerformCorrectEnqueuesResult() async throws {
        let id = UUID()
        let before = Date()

        _ = try await RegisterWidgetResultIntent(wordID: id, correct: true).perform()

        let queued = WidgetResultQueue.load()
        XCTAssertEqual(queued.count, 1)
        XCTAssertEqual(queued.first?.wordID, id)
        XCTAssertEqual(queued.first?.correct, true)
        let date = try XCTUnwrap(queued.first?.date)
        // ISO-8601 in der Queue speichert nur ganze Sekunden.
        XCTAssertEqual(date.timeIntervalSince1970, before.timeIntervalSince1970, accuracy: 2)
    }

    /// „Nochmal" legt einen Eintrag mit `correct == false` ab.
    func testPerformWrongEnqueuesResult() async throws {
        let id = UUID()

        _ = try await RegisterWidgetResultIntent(wordID: id, correct: false).perform()

        let queued = WidgetResultQueue.load()
        XCTAssertEqual(queued.map(\.wordID), [id])
        XCTAssertEqual(queued.first?.correct, false)
    }

    /// Der Komfort-Init legt die UUID als String ab (AppIntent-Parameter kennen kein `UUID`).
    func testInitStoresUUIDString() {
        let id = UUID()
        let intent = RegisterWidgetResultIntent(wordID: id, correct: true)

        XCTAssertEqual(intent.wordID, id.uuidString)
        XCTAssertTrue(intent.correct)
    }

    /// Eine nicht parsebare Wort-ID wird stillschweigend verworfen – kein Crash, keine Queue.
    func testPerformWithInvalidIDEnqueuesNothing() async throws {
        let intent = RegisterWidgetResultIntent()
        intent.wordID = "kein-uuid"
        intent.correct = true

        _ = try await intent.perform()

        XCTAssertTrue(WidgetResultQueue.load().isEmpty)
    }

    // MARK: - perform() → Queue → Reconciler → Vocab

    /// Ende-zu-Ende: Widget-Tipp landet nach dem Drain der App im Vokabel-Modell.
    func testPerformThenDrainUpdatesVocab() async throws {
        let vocab = insert("가다")

        _ = try await RegisterWidgetResultIntent(wordID: vocab.id, correct: true).perform()
        // Tap-Zeitpunkt aus der Queue als Bezugstag – so bleibt der Test auch um Mitternacht stabil.
        let tapDate = try XCTUnwrap(WidgetResultQueue.load().first?.date)
        let changed = WidgetResultReconciler.drain(context: context)

        XCTAssertTrue(changed)
        XCTAssertEqual(vocab.successCounter, 1)
        XCTAssertEqual(vocab.timesPracticed, 1)
        XCTAssertFalse(vocab.lastAnswerWasWrong)
        XCTAssertTrue(WidgetResultQueue.load().isEmpty, "Queue muss nach dem Drain leer sein")
        // Auch die geteilten Zähler müssen den Widget-Tipp sehen (Streak + Wochenrückblick).
        XCTAssertEqual(StreakStore.displayStreak(asOf: tapDate), 1)
        XCTAssertEqual(WeeklyReviewStore.dayProgress(for: .practiced, asOf: tapDate), 1)
    }

    /// Ein Tipp auf ein inzwischen gelöschtes/unbekanntes Wort verbucht nichts, die Queue
    /// wird trotzdem geleert und vorhandene Wörter bleiben unberührt.
    func testPerformWithUnknownVocabIDIsDroppedOnDrain() async throws {
        let existing = insert("오다")

        _ = try await RegisterWidgetResultIntent(wordID: UUID(), correct: true).perform()
        let changed = WidgetResultReconciler.drain(context: context)

        XCTAssertFalse(changed)
        XCTAssertTrue(WidgetResultQueue.load().isEmpty, "Unbekannte IDs müssen aus der Queue fallen")
        XCTAssertEqual(existing.timesPracticed, 0)
        XCTAssertEqual(existing.successCounter, 0)
    }

    /// Doppelter Tap auf „Gewusst" am selben Tag: beide Tipps landen in der Queue und zählen
    /// als Übung, der Lern-Counter steigt aber nur einmal (Pro-Tag-Idempotenz von
    /// `Vocab.registerResult`).
    func testDoubleTapCountsOncePerDay() async throws {
        let vocab = insert("보다")
        let intent = RegisterWidgetResultIntent(wordID: vocab.id, correct: true)

        _ = try await intent.perform()
        _ = try await intent.perform()
        let queued = WidgetResultQueue.load()
        XCTAssertEqual(queued.count, 2)
        // Jeder Tap stempelt seine eigene Uhrzeit. Fallen beide (selten) auf verschiedene
        // Kalendertage – Testlauf genau um Mitternacht –, zählen beide; sonst nur einer.
        let sameDay = Calendar.current.isDate(queued[0].date, inSameDayAs: queued[1].date)

        WidgetResultReconciler.drain(context: context)

        XCTAssertEqual(vocab.timesPracticed, 2)
        XCTAssertEqual(vocab.successCounter, sameDay ? 1 : 2)
        XCTAssertTrue(WidgetResultQueue.load().isEmpty)
    }
}
