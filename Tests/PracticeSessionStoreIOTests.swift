@testable import DailyHangul
import SwiftData
import XCTest

/// Prüft die gebündelte Store-Persistenz im Übungs-Hotpath (#70): Streak wird je
/// Kalendertag nur einmal verbucht, der Wochen-Log im Speicher gesammelt und gebündelt
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

    /// Runde über Mitternacht (Issue #178): Antworten vor und nach 0 Uhr verbuchen beide
    /// Kalendertage als Streak-Aktivität – nicht nur den Tag der ersten Antwort.
    func testSessionAcrossMidnightRegistersBothDays() throws {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let tomorrow = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: today))
        let beforeMidnight = try XCTUnwrap(calendar.date(byAdding: .minute, value: -1, to: tomorrow))
        let afterMidnight = try XCTUnwrap(calendar.date(byAdding: .minute, value: 1, to: tomorrow))

        // 4 Wörter, nur 3 beantwortet: Runde bleibt offen, damit `finalizeRound` keine
        // auf morgen datierten Badges/Tages-Challenge in den geteilten Defaults hinterlässt.
        let session = makeSession(makeVocabs(4))
        session.now = { beforeMidnight }
        session.submit(correct: true)
        session.submit(correct: false)
        session.now = { afterMidnight }
        session.submit(correct: true)

        XCTAssertEqual(StreakStore.activeDays, [today, tomorrow])
        XCTAssertEqual(StreakStore.current, 2)
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

    /// Früher Flush (z.B. Backgrounding) und anschließendes Fertigspielen darf nicht
    /// doppelt zählen: der Rundenend-Flush schreibt denselben, weitergesammelten Stand.
    func testMidRoundFlushThenFinishDoesNotDoubleCount() {
        let session = makeSession(makeVocabs(5))
        session.submit(correct: true)
        session.submit(correct: true)
        session.flushProgress() // Backgrounding mitten in der Runde
        XCTAssertEqual(WeeklyReviewStore.dayProgress(for: .practiced), 2)

        for _ in 0 ..< 3 { session.submit(correct: true) } // Runde zu Ende → finalizeRound flusht
        XCTAssertTrue(session.isFinished)
        XCTAssertEqual(WeeklyReviewStore.dayProgress(for: .practiced), 5)
    }

    /// `restart()` setzt den gesammelten Wochen-Log nicht zurück: dieselben Wörter noch
    /// einmal zu üben bleibt distinct-dedupliziert (identisch zum Per-Karte-Schreiben).
    func testRestartKeepsWeeklyProgressDeduplicated() {
        let vocabs = makeVocabs(4)
        let session = makeSession(vocabs)
        for _ in 0 ..< 4 { session.submit(correct: true) }
        XCTAssertEqual(WeeklyReviewStore.dayProgress(for: .practiced), 4)

        session.restart()
        for _ in 0 ..< 4 { session.submit(correct: true) }

        XCTAssertEqual(WeeklyReviewStore.dayProgress(for: .practiced), 4)
    }
}
