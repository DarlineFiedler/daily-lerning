@testable import DailyHangul
import SwiftData
import XCTest

/// Prüft den eigenständigen Endgegner-Kampf (Folge zu #89): HP sinkt pro besiegtem
/// Wort, nur falsche Wörter werden wiederholt, Sieg/Niederlage/Aufgeben – und vor
/// allem die **Statistik-Neutralität** (der Kampf fasst die Lern-Daten nicht an).
@MainActor
final class BossSessionTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUp() {
        super.setUp()
        container = PersistenceController.makeContainer(inMemory: true)
        context = container.mainContext
        // Frischer Achievement-Stand, damit die Badge-Assertions deterministisch sind.
        AchievementStore.progress = AchievementProgress()
    }

    override func tearDown() {
        context = nil
        container = nil
        super.tearDown()
    }

    private func makeVocabs(_ count: Int, group: VocabGroup? = nil) -> [Vocab] {
        (0 ..< count).map { i in
            let v = Vocab(word: "단어\(i)", meaning: "Wort \(i)", group: group)
            context.insert(v)
            return v
        }
    }

    private func makeGroup(_ name: String) -> VocabGroup {
        let g = VocabGroup(name: name)
        context.insert(g)
        return g
    }

    private func makeSession(_ vocabs: [Vocab], distractors: [Vocab]? = nil) -> BossSession {
        BossSession(vocabs: vocabs, distractorPool: distractors ?? vocabs,
                    config: PracticeConfig(modes: [.review]), context: context)
    }

    /// Alle Wörter richtig → Boss auf 0 HP → Sieg, Badge (statistik-neutral) vergeben.
    func testVictoryWhenAllWordsDefeated() {
        let s = makeSession(makeVocabs(5))
        XCTAssertEqual(s.totalWords, 5)
        XCTAssertEqual(s.battle.currentHP, 5)
        for _ in 0 ..< 5 { s.answer(correct: true) }
        XCTAssertEqual(s.outcome, .victory)
        XCTAssertEqual(s.battle.currentHP, 0)
        XCTAssertEqual(s.correctCount, 5)
        XCTAssertTrue(AchievementStore.progress.bossDefeated)
    }

    /// Nur die falschen Wörter kommen im nächsten Durchgang wieder – die richtigen
    /// scheiden aus. Bei 3 Wörtern mit einem Fehler sind es genau 4 Antworten.
    func testOnlyWrongWordsRepeat() {
        let s = makeSession(makeVocabs(3)) // maxLives = 3
        XCTAssertEqual(s.round, 1)
        s.answer(correct: false) // 1 Wort daneben → wandert in den nächsten Durchgang
        s.answer(correct: true)
        s.answer(correct: true) // Durchgang 1 durch: 2 besiegt, 1 offen
        XCTAssertTrue(s.isFighting)
        XCTAssertEqual(s.round, 2)
        XCTAssertNotNil(s.currentItem)
        XCTAssertEqual(s.correctCount, 2)
        // Genau ein Wort ist offen → ein weiterer Treffer gewinnt.
        s.answer(correct: true)
        XCTAssertEqual(s.outcome, .victory)
        XCTAssertEqual(s.correctCount, 3)
        XCTAssertEqual(s.turns, 4) // 3 richtig + 1 falsch → nur das falsche kam wieder
    }

    /// Zu viele Fehler → Leben aufgebraucht → Niederlage, kein Badge.
    func testDefeatWhenLivesExhausted() {
        let s = makeSession(makeVocabs(10)) // maxLives = ceil(10*0.34) = 4
        XCTAssertEqual(s.battle.maxLives, 4)
        for _ in 0 ..< 4 { s.answer(correct: false) }
        XCTAssertEqual(s.outcome, .defeat)
        XCTAssertTrue(s.battle.isPlayerDefeated)
        XCTAssertEqual(s.correctCount, 0)
        XCTAssertFalse(AchievementStore.progress.bossDefeated)
    }

    /// Aufgeben beendet als Niederlage – ohne Badge.
    func testGiveUpEndsAsDefeatWithoutBadge() {
        let s = makeSession(makeVocabs(5))
        s.answer(correct: true)
        s.giveUp()
        XCTAssertEqual(s.outcome, .defeat)
        XCTAssertTrue(s.newlyUnlocked.isEmpty)
        XCTAssertFalse(AchievementStore.progress.bossDefeated)
    }

    /// Nach dem Sieg ändern weitere Antworten nichts mehr (idempotentes Ende).
    func testAnswersAfterEndAreIgnored() {
        let s = makeSession(makeVocabs(3))
        for _ in 0 ..< 3 { s.answer(correct: true) }
        XCTAssertEqual(s.outcome, .victory)
        let hits = s.correctCount
        s.answer(correct: false)
        s.answer(correct: true)
        XCTAssertEqual(s.correctCount, hits)
        XCTAssertEqual(s.wrongCount, 0)
    }

    /// Kernversprechen: Der Kampf schreibt **nichts** in die Lern-Daten.
    func testBattleDoesNotTouchLearningData() {
        let vocabs = makeVocabs(4)
        let s = makeSession(vocabs)
        s.answer(correct: true)
        s.answer(correct: false)
        s.answer(correct: true)
        while s.isFighting { s.answer(correct: true) } // Runde sauber zu Ende bringen
        for v in vocabs {
            XCTAssertEqual(v.timesPracticed, 0, "Kampf darf timesPracticed nicht erhöhen")
            XCTAssertEqual(v.successCounter, 0, "Kampf darf den Erfolgs-Counter nicht ändern")
            XCTAssertEqual(v.statusRaw, LearningStatus.new.rawValue, "Kampf darf den Status nicht ändern")
        }
    }

    /// Boss-Identität = die einzige Gruppe der Runde; sonst generischer Boss (nil).
    func testBossGroupIsSingleDistinctGroup() {
        let groupA = makeGroup("A")
        let single = BossSession(vocabs: makeVocabs(3, group: groupA), distractorPool: [],
                                 config: PracticeConfig(modes: [.review]), context: context)
        XCTAssertEqual(single.bossGroup?.id, groupA.id)

        let groupB = makeGroup("B")
        let mixed = BossSession(vocabs: makeVocabs(2, group: groupA) + makeVocabs(2, group: groupB),
                                distractorPool: [], config: PracticeConfig(modes: [.review]), context: context)
        XCTAssertNil(mixed.bossGroup)
    }

    /// Leere Runde: kein Kampf, keine Karte.
    func testEmptyRoundHasNoFight() {
        let s = makeSession([])
        XCTAssertEqual(s.totalWords, 0)
        XCTAssertNil(s.currentItem)
        XCTAssertNil(s.outcome)
    }
}
