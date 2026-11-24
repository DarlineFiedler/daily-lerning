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
                    StreakKeys.activeDays, WeeklyReviewKeys.log, XPKeys.state,
                    DailyChallengeKeys.state, AchievementKeys.unlockedIDs, AchievementKeys.unlockDates] {
            d.removeObject(forKey: key)
        }
    }

    private func makeSession(_ count: Int, modes: [PracticeMode] = [.review],
                             groups: [VocabGroup] = []) -> PracticeSession {
        let vocabs = (0 ..< count).map { i in
            let v = Vocab(word: "단어\(i)", meaning: "Wort \(i)",
                          group: groups.isEmpty ? nil : groups[i % groups.count])
            context.insert(v)
            return v
        }
        return PracticeSession(vocabs: vocabs, distractorPool: vocabs,
                               config: PracticeConfig(modes: Set(modes)), context: context)
    }

    private func makeGroup(_ name: String) -> VocabGroup {
        let g = VocabGroup(name: name)
        context.insert(g)
        return g
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

    /// Timeout schaltet Badges frei → die Session gibt sie für das Freischalt-Banner heraus (#168).
    func testFinishEarlyExposesNewlyUnlockedBadges() {
        let session = makeSession(5)
        session.submit(correct: true)

        session.finishEarly()

        XCTAssertTrue(session.newlyUnlocked.map(\.id).contains("sessions1"))
    }

    /// Neustart nach Timeout setzt die frisch freigeschalteten Badges zurück (kein Banner-Rest).
    func testRestartAfterFinishEarlyClearsNewlyUnlocked() {
        let session = makeSession(5)
        session.submit(correct: true)
        session.finishEarly()
        XCTAssertFalse(session.newlyUnlocked.isEmpty)

        session.restart()

        XCTAssertTrue(session.newlyUnlocked.isEmpty)
    }

    /// Timeout ohne Antwort schaltet nichts frei → kein Banner.
    func testFinishEarlyWithoutAnswersUnlocksNothing() {
        let session = makeSession(5)

        session.finishEarly()

        XCTAssertTrue(session.newlyUnlocked.isEmpty)
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

    /// Nur gesehene Karten zählen: Modi und Gruppen ungesehener Karten werden nicht verbucht.
    func testFinishEarlyCountsOnlyAnsweredModesAndGroups() {
        let groups = (0 ..< 4).map { makeGroup("G\($0)") }
        let session = makeSession(12, modes: [.review, .multipleChoice, .writing], groups: groups)
        let answered = session.items[0]
        session.submit(correct: true)

        session.finishEarly()

        let progress = AchievementStore.progress
        XCTAssertEqual(progress.modesUsed, [answered.mode.rawValue])
        XCTAssertEqual(progress.groupsToday, Set([answered.vocab.group?.id.uuidString].compactMap { $0 }))
    }

    /// Timeout ohne Fehler lässt eine laufende Fehlerfrei-Serie unberührt.
    func testFinishEarlyWithoutMistakesKeepsFlawlessRun() {
        var progress = AchievementProgress()
        progress.flawlessRun = RoundRun(run: 3, best: 3)
        AchievementStore.progress = progress
        let session = makeSession(6)
        session.submit(correct: true)

        session.finishEarly()

        XCTAssertEqual(AchievementStore.progress.flawlessRun.run, 3)
    }

    /// Timeout nach einem echten Fehler bricht die Fehlerfrei-Serie wie gewohnt ab.
    func testFinishEarlyWithMistakeBreaksFlawlessRun() {
        var progress = AchievementProgress()
        progress.flawlessRun = RoundRun(run: 3, best: 3)
        AchievementStore.progress = progress
        let session = makeSession(6)
        session.submit(correct: false)

        session.finishEarly()

        XCTAssertEqual(AchievementStore.progress.flawlessRun.run, 0)
        XCTAssertEqual(AchievementStore.progress.flawlessRun.best, 3)
    }
}
