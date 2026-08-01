@testable import DailyHangul
import XCTest

/// Prüft die reine Endgegner-Kampf-Logik (Issue #89): Boss-HP sinkt mit Treffern,
/// Leben skalieren mit der Rundengröße, zu viele Fehler bedeuten Niederlage.
final class BossBattleTests: XCTestCase {

    func testMaxLivesScalesWithMinimumThree() {
        // Kleine Runden: Mindestens 3 Leben, damit es fair bleibt.
        XCTAssertEqual(BossBattle.maxLives(forTotalWords: 1), 3)
        XCTAssertEqual(BossBattle.maxLives(forTotalWords: 8), 3) // ceil(8*0.34)=3
        // Größere Runden: ~ein Drittel, aufgerundet.
        XCTAssertEqual(BossBattle.maxLives(forTotalWords: 10), 4) // ceil(3.4)=4
        XCTAssertEqual(BossBattle.maxLives(forTotalWords: 20), 7) // ceil(6.8)=7
    }

    func testEmptyRoundHasNoBattle() {
        let battle = BossBattle(total: 0, correct: 0, wrong: 0)
        XCTAssertEqual(battle.maxLives, 0)
        XCTAssertEqual(battle.currentHP, 0)
        XCTAssertEqual(battle.hpFraction, 0)
        XCTAssertFalse(battle.isPlayerDefeated) // kein Kampf → keine Niederlage
        XCTAssertTrue(battle.playerWon)
    }

    func testBossHPDropsWithCorrectAnswers() {
        let full = BossBattle(total: 10, correct: 0, wrong: 0)
        XCTAssertEqual(full.currentHP, 10)
        XCTAssertEqual(full.hpFraction, 1)

        let dented = BossBattle(total: 10, correct: 4, wrong: 0)
        XCTAssertEqual(dented.currentHP, 6)
        XCTAssertEqual(dented.hpFraction, 0.6, accuracy: 0.0001)

        let slain = BossBattle(total: 10, correct: 10, wrong: 0)
        XCTAssertEqual(slain.currentHP, 0)
        XCTAssertEqual(slain.hpFraction, 0)
    }

    func testLivesDrainWithWrongAnswers() {
        let battle = BossBattle(total: 10, correct: 3, wrong: 2) // maxLives 4
        XCTAssertEqual(battle.maxLives, 4)
        XCTAssertEqual(battle.livesRemaining, 2)
        XCTAssertEqual(battle.livesFraction, 0.5, accuracy: 0.0001)
        XCTAssertFalse(battle.isPlayerDefeated)
        XCTAssertTrue(battle.playerWon)
    }

    func testPlayerDefeatedWhenLivesExhausted() {
        // maxLives 4 → der 4. Fehler bringt die Spielerin auf 0 Leben (k.o.).
        let defeated = BossBattle(total: 10, correct: 2, wrong: 4)
        XCTAssertEqual(defeated.livesRemaining, 0)
        XCTAssertTrue(defeated.isPlayerDefeated)
        XCTAssertFalse(defeated.playerWon)
    }

    func testNegativeInputsAreClampedToZero() {
        let battle = BossBattle(total: -5, correct: -1, wrong: -3)
        XCTAssertEqual(battle.maxHP, 0)
        XCTAssertEqual(battle.correct, 0)
        XCTAssertEqual(battle.wrong, 0)
    }
}
