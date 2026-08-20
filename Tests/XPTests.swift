@testable import DailyHangul
import XCTest

final class XPTests: XCTestCase {
    // MARK: - Level-Kurve

    func testThresholdCurve() {
        // 50 * (n-1) * n: L1=0, L2=100, L3=300, L4=600, L5=1000.
        XCTAssertEqual(XPLevel.threshold(forLevel: 1), 0)
        XCTAssertEqual(XPLevel.threshold(forLevel: 2), 100)
        XCTAssertEqual(XPLevel.threshold(forLevel: 3), 300)
        XCTAssertEqual(XPLevel.threshold(forLevel: 4), 600)
        XCTAssertEqual(XPLevel.threshold(forLevel: 5), 1000)
    }

    func testLevelForXPInvertsThresholdAtBoundaries() {
        XCTAssertEqual(XPLevel.level(forXP: 0), 1)
        XCTAssertEqual(XPLevel.level(forXP: 99), 1)
        XCTAssertEqual(XPLevel.level(forXP: 100), 2)
        XCTAssertEqual(XPLevel.level(forXP: 299), 2)
        XCTAssertEqual(XPLevel.level(forXP: 300), 3)
        XCTAssertEqual(XPLevel.level(forXP: 599), 3)
        XCTAssertEqual(XPLevel.level(forXP: 600), 4)
        XCTAssertEqual(XPLevel.level(forXP: 999), 4)
        XCTAssertEqual(XPLevel.level(forXP: 1000), 5)
    }

    func testLevelForXPNeverBelowOneAndHandlesNegative() {
        XCTAssertEqual(XPLevel.level(forXP: -50), 1)
        XCTAssertEqual(XPLevel.forXP(-50).level, 1)
        XCTAssertEqual(XPLevel.forXP(-50).totalXP, 0)
    }

    func testLevelForXPMonotonicOverRange() {
        // Über einen breiten Bereich darf das Level nie fallen und stets zur Schwelle passen.
        var previous = 1
        for xp in stride(from: 0, through: 20_000, by: 37) {
            let level = XPLevel.level(forXP: xp)
            XCTAssertGreaterThanOrEqual(level, previous)
            XCTAssertLessThanOrEqual(XPLevel.threshold(forLevel: level), xp)
            XCTAssertGreaterThan(XPLevel.threshold(forLevel: level + 1), xp)
            previous = level
        }
    }

    // MARK: - Ränge

    func testRankBands() {
        // Rangwechsel alle 3 Level, gedeckelt bei 7.
        XCTAssertEqual(XPLevel.rankIndex(forLevel: 1), 0)
        XCTAssertEqual(XPLevel.rankIndex(forLevel: 3), 0)
        XCTAssertEqual(XPLevel.rankIndex(forLevel: 4), 1)
        XCTAssertEqual(XPLevel.rankIndex(forLevel: 6), 1)
        XCTAssertEqual(XPLevel.rankIndex(forLevel: 22), 7)
        XCTAssertEqual(XPLevel.rankIndex(forLevel: 999), 7, "Rang ist bei rankCount-1 gedeckelt")
    }

    func testRankKey() {
        XCTAssertEqual(XPLevel.forXP(0).rankKey, "xp.rank.0")
    }

    // MARK: - XP-Formel

    func testBasePoints() {
        // Kombo 1 (kein Bonus), gelerntes Wort (kein Schwierigkeitsbonus) → nur Basis.
        XCTAssertEqual(XPRules.points(combo: 1, status: .learned), XPRules.base)
    }

    func testComboBonusStepsAndCap() {
        XCTAssertEqual(XPRules.comboBonus(0), 0)
        XCTAssertEqual(XPRules.comboBonus(1), 0)
        XCTAssertEqual(XPRules.comboBonus(2), 2)
        XCTAssertEqual(XPRules.comboBonus(3), 4)
        // Gedeckelt: ab comboBonusCap+1 Kombo-Stufen wächst der Bonus nicht weiter.
        XCTAssertEqual(XPRules.comboBonus(XPRules.comboBonusCap + 1), XPRules.comboBonusCap * 2)
        XCTAssertEqual(XPRules.comboBonus(100), XPRules.comboBonusCap * 2)
    }

    func testDifficultyBonusByStatus() {
        XCTAssertEqual(XPRules.difficultyBonus(.new), 6)
        XCTAssertEqual(XPRules.difficultyBonus(.learning), 4)
        XCTAssertEqual(XPRules.difficultyBonus(.almostLearned), 2)
        XCTAssertEqual(XPRules.difficultyBonus(.learned), 0)
    }

    func testPointsCombineBaseComboAndDifficulty() {
        // Basis 10 + Kombo-Bonus(3)=4 + Schwierigkeit(.new)=6 = 20.
        XCTAssertEqual(XPRules.points(combo: 3, status: .new), 20)
    }

    // MARK: - XPState

    func testAwardingIsAdditive() {
        let state = XPState().awarding(30).awarding(20)
        XCTAssertEqual(state.totalXP, 50)
    }

    func testAwardingClampsNegativePoints() {
        let state = XPState(totalXP: 40).awarding(-100)
        XCTAssertEqual(state.totalXP, 40, "Negative Punkte ändern den Stand nicht")
    }

    // MARK: - XPStore (Persistenz über AppGroup.defaults)

    override func setUp() {
        super.setUp()
        AppGroup.defaults.removeObject(forKey: XPKeys.state)
    }

    override func tearDown() {
        AppGroup.defaults.removeObject(forKey: XPKeys.state)
        super.tearDown()
    }

    func testStorePersistsAndAccumulates() {
        XCTAssertEqual(XPStore.totalXP, 0)
        XPStore.award(40)
        XCTAssertEqual(XPStore.totalXP, 40)
        XPStore.award(70)
        XCTAssertEqual(XPStore.totalXP, 110)
        XCTAssertEqual(XPStore.level.level, 2)
    }

    func testAwardReportsLevelUp() {
        // Von 90 (Level 1) auf 110 (Level 2) → Levelaufstieg, aber kein Rangwechsel.
        XPStore.award(90)
        let award = XPStore.award(20)
        XCTAssertEqual(award.points, 20)
        XCTAssertEqual(award.before.level, 1)
        XCTAssertEqual(award.after.level, 2)
        XCTAssertTrue(award.didLevelUp)
        XCTAssertEqual(award.after.rankIndex, award.before.rankIndex, "Levelaufstieg ohne Rangwechsel")
    }

    func testAwardReportsRankUp() {
        // Level 3 (300 XP) → Level 4 (600 XP) überschreitet die erste Rang-Grenze.
        XPStore.award(300)
        XCTAssertEqual(XPStore.level.level, 3)
        XCTAssertEqual(XPStore.level.rankIndex, 0)
        let award = XPStore.award(300)
        XCTAssertEqual(award.after.level, 4)
        XCTAssertTrue(award.didLevelUp)
        XCTAssertGreaterThan(award.after.rankIndex, award.before.rankIndex, "erste Rang-Grenze überschritten")
        XCTAssertEqual(award.after.rankIndex, 1)
    }

    func testNoLevelUpWithinSameLevel() {
        XPStore.award(10)
        let award = XPStore.award(10)
        XCTAssertFalse(award.didLevelUp)
        XCTAssertEqual(award.after.level, 1)
    }
}
