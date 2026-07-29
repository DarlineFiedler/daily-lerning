@testable import DailyHangul
import SwiftData
import XCTest

/// Prüft die gebündelte Store-Persistenz im Übungs-Hotpath (#70): Streak wird pro
/// Session nur einmal verbucht, der Wochen-Log im Speicher gesammelt und gebündelt
/// zurückgeschrieben – das Ergebnis muss identisch zum Per-Karte-Schreiben bleiben.
/// Schreibt in `AppGroup.defaults`; die betroffenen Keys werden je Test zurückgesetzt.
@MainActor
final class PracticeSessionStoreIOTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUp() {
        super.setUp()
        container = PersistenceController.makeContainer(inMemory: true)
        context = container.mainContext
        resetStores()
    }

    override func tearDown() {
        resetStores()
        context = nil
        container = nil
        super.tearDown()
    }

    private func resetStores() {
        let d = AppGroup.defaults
        for key in [StreakKeys.current, StreakKeys.longest, StreakKeys.lastActiveDay,
                    StreakKeys.jokers, StreakKeys.weekAnchor, StreakKeys.jokerUses,
                    StreakKeys.activeDays, WeeklyReviewKeys.log] {
            d.removeObject(forKey: key)
        }
    }

    private func makeVocabs(_ count: Int) -> [Vocab] {
        (0 ..< count).map { i in
            let v = Vocab(word: "단어\(i)", meaning: "Wort \(i)")
            context.insert(v)
            return v
        }
    }

    private func makeSession(_ vocabs: [Vocab]) -> PracticeSession {
        PracticeSession(vocabs: vocabs, distractorPool: vocabs,
                        config: PracticeConfig(modes: [.review]), context: context)
    }

    /// Fertige Runde: Streak steht bei 1 und heute ist genau einmal als aktiver Tag
    /// verbucht – trotz mehrerer beantworteter Karten (einmalige, idempotente Buchung).
    func testFinishedSessionRegistersStreakOnce() {
        let session = makeSession(makeVocabs(4))
        for _ in 0 ..< 4 { session.submit(correct: true) }

        XCTAssertEqual(StreakStore.current, 1)
        let today = Calendar.current.startOfDay(for: .now)
        XCTAssertEqual(StreakStore.activeDays, [today])
    }

    /// Fertige Runde: der Wochen-Log ist gebündelt persistiert – der Tagesfortschritt
    /// zählt jedes distinct geübte Wort (identisch zum vorherigen Per-Karte-Schreiben).
    func testFinishedSessionPersistsWeeklyProgress() {
        let session = makeSession(makeVocabs(5))
        for _ in 0 ..< 5 { session.submit(correct: true) }

        XCTAssertEqual(WeeklyReviewStore.dayProgress(for: .practiced), 5)
    }

    /// Früh abgebrochene Runde: `flushProgress()` (vom View-Teardown ausgelöst)
    /// persistiert die bis dahin gesammelten Karten.
    func testEarlyFlushPersistsPartialProgress() {
        let session = makeSession(makeVocabs(6))
        session.submit(correct: true)
        session.submit(correct: false)
        XCTAssertFalse(session.isFinished)
        // Noch nichts geschrieben, solange nicht geflusht wurde.
        XCTAssertEqual(WeeklyReviewStore.dayProgress(for: .practiced), 0)

        session.flushProgress()
        XCTAssertEqual(WeeklyReviewStore.dayProgress(for: .practiced), 2)
    }

    /// Wiederholtes Flushen schreibt nur denselben Stand zurück (keine Doppelzählung).
    func testRepeatedFlushIsIdempotent() {
        let session = makeSession(makeVocabs(3))
        session.submit(correct: true)
        session.flushProgress()
        session.flushProgress()

        XCTAssertEqual(WeeklyReviewStore.dayProgress(for: .practiced), 1)
    }
}
