@testable import DailyHangul
import SwiftData
import XCTest

/// Prüft das vorzeitige Rundenende (Issue #134, z.B. Prüfungs-Timeout): die Runde zählt als
/// abgeschlossene Session, aber nie als perfekt/fehlerfrei; ohne Antwort wird nichts verbucht.
@MainActor
final class PracticeSessionFinishEarlyTests: XCTestCase {

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
        AchievementStore.progress = AchievementProgress()
        let d = AppGroup.defaults
        for key in [StreakKeys.current, StreakKeys.longest, StreakKeys.lastActiveDay,
                    StreakKeys.jokers, StreakKeys.weekAnchor, StreakKeys.jokerUses,
                    StreakKeys.activeDays, WeeklyReviewKeys.log] {
            d.removeObject(forKey: key)
        }
    }

    private func makeSession(_ count: Int) -> PracticeSession {
        let vocabs = (0 ..< count).map { i in
            let v = Vocab(word: "단어\(i)", meaning: "Wort \(i)")
            context.insert(v)
            return v
        }
        return PracticeSession(vocabs: vocabs, distractorPool: vocabs,
                               config: PracticeConfig(modes: [.review]), context: context)
    }

    /// Teilweise beantwortet + Timeout → eine abgeschlossene, nicht-perfekte Session.
    func testFinishEarlyCountsAsCompletedSession() {
        let session = makeSession(6)
        session.submit(correct: true)
        session.submit(correct: false)
        session.submit(correct: true)

        session.finishEarly()

        XCTAssertEqual(AchievementStore.progress.sessionsCompleted, 1)
        XCTAssertEqual(AchievementStore.progress.perfectRounds, 0)
    }

    /// Nur richtige Antworten, aber unbeantwortete Karten → weder „Makellos" noch fehlerfrei.
    func testFinishEarlyIsNeverPerfectOrFlawless() {
        let session = makeSession(8)
        for _ in 0 ..< 5 { session.submit(correct: true) }

        session.finishEarly()

        let progress = AchievementStore.progress
        XCTAssertEqual(progress.sessionsCompleted, 1)
        XCTAssertEqual(progress.perfectRounds, 0)
        XCTAssertFalse(progress.flawlessToday)
    }

    /// Timeout ohne eine einzige Antwort → keine Session verbucht.
    func testFinishEarlyWithoutAnswersDoesNotCountSession() {
        let session = makeSession(5)

        session.finishEarly()

        XCTAssertEqual(AchievementStore.progress.sessionsCompleted, 0)
    }

    /// Mehrfaches vorzeitiges Beenden zählt nur einmal.
    func testFinishEarlyIsIdempotent() {
        let session = makeSession(5)
        session.submit(correct: true)

        session.finishEarly()
        session.finishEarly()

        XCTAssertEqual(AchievementStore.progress.sessionsCompleted, 1)
    }

    /// Eine regulär beendete Runde ist schon finalisiert – `finishEarly` verbucht nichts doppelt
    /// und überschreibt die perfekte Wertung nicht.
    func testFinishEarlyAfterRegularFinishIsNoOp() {
        let session = makeSession(5)
        for _ in 0 ..< 5 { session.submit(correct: true) }
        XCTAssertTrue(session.isFinished)

        session.finishEarly()

        XCTAssertEqual(AchievementStore.progress.sessionsCompleted, 1)
        XCTAssertEqual(AchievementStore.progress.perfectRounds, 1)
    }

    /// Nach Timeout + Neustart wird die nächste Runde wieder regulär verbucht.
    func testRestartAfterFinishEarlyCountsNextRound() {
        let session = makeSession(5)
        session.submit(correct: true)
        session.finishEarly()

        session.restart()
        for _ in 0 ..< 5 { session.submit(correct: true) }

        XCTAssertEqual(AchievementStore.progress.sessionsCompleted, 2)
        XCTAssertEqual(AchievementStore.progress.perfectRounds, 1)
    }

    /// Der gesammelte Wochen-Log wird beim vorzeitigen Ende persistiert.
    func testFinishEarlyPersistsWeeklyProgress() {
        let session = makeSession(6)
        session.submit(correct: true)
        session.submit(correct: false)

        session.finishEarly()

        XCTAssertEqual(WeeklyReviewStore.dayProgress(for: .practiced), 2)
    }
}
