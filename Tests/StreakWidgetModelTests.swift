@testable import DailyHangul
import XCTest

final class StreakWidgetModelTests: XCTestCase {

    // MARK: - Reine Auswahllogik (make)

    func testNoGoalYieldsStreakOnly() {
        let m = StreakWidgetModel.make(streak: 5, longest: 9,
                                       daily: (3, 0), weekly: (12, 0))
        XCTAssertEqual(m.streak, 5)
        XCTAssertEqual(m.longest, 9)
        XCTAssertNil(m.goal, "Ohne gesetztes Ziel zeigt das Widget keinen Ring")
    }

    func testDailyGoalTakesPrecedenceOverWeekly() throws {
        let m = StreakWidgetModel.make(streak: 2, longest: 2,
                                       daily: (3, 5), weekly: (12, 30))
        let goal = try XCTUnwrap(m.goal)
        XCTAssertTrue(goal.isDaily)
        XCTAssertEqual(goal.done, 3)
        XCTAssertEqual(goal.target, 5)
    }

    func testWeeklyGoalUsedWhenNoDailyGoal() throws {
        let m = StreakWidgetModel.make(streak: 2, longest: 2,
                                       daily: (3, 0), weekly: (12, 30))
        let goal = try XCTUnwrap(m.goal)
        XCTAssertFalse(goal.isDaily)
        XCTAssertEqual(goal.done, 12)
        XCTAssertEqual(goal.target, 30)
    }

    func testFractionIsClampedToOne() {
        let goal = StreakWidgetModel.GoalProgress(done: 15, target: 10, isDaily: true)
        XCTAssertEqual(goal.fraction, 1, accuracy: 0.0001)
        XCTAssertTrue(goal.reached)
    }

    func testFractionAndReachedBelowTarget() {
        let goal = StreakWidgetModel.GoalProgress(done: 3, target: 10, isDaily: true)
        XCTAssertEqual(goal.fraction, 0.3, accuracy: 0.0001)
        XCTAssertFalse(goal.reached)
    }

    func testReachedExactlyAtTarget() {
        let goal = StreakWidgetModel.GoalProgress(done: 10, target: 10, isDaily: false)
        XCTAssertTrue(goal.reached)
        XCTAssertEqual(goal.fraction, 1, accuracy: 0.0001)
    }

    // MARK: - Integration gegen den geteilten App-Group-Zustand (current)

    private let touchedKeys = [
        StreakKeys.current, StreakKeys.longest, StreakKeys.lastActiveDay,
        StreakKeys.jokers, StreakKeys.weekAnchor, StreakKeys.jokerUses, StreakKeys.activeDays,
        WeeklyReviewKeys.log, GoalKeys.metric, GoalKeys.daily, GoalKeys.weekly
    ]

    override func setUp() {
        super.setUp()
        clearSharedState()
    }

    override func tearDown() {
        clearSharedState()
        super.tearDown()
    }

    private func clearSharedState() {
        touchedKeys.forEach { AppGroup.defaults.removeObject(forKey: $0) }
    }

    func testCurrentReadsStreakAndDailyGoalFromSharedState() throws {
        AppGroup.defaults.set(GoalMetric.practiced.rawValue, forKey: GoalKeys.metric)
        AppGroup.defaults.set(5, forKey: GoalKeys.daily)
        AppGroup.defaults.set(0, forKey: GoalKeys.weekly)

        StreakStore.registerActivity() // heute aktiv → Streak 1
        WeeklyReviewStore.record(wordID: UUID(), becameLearned: false, correct: true)
        WeeklyReviewStore.record(wordID: UUID(), becameLearned: false, correct: true)

        let m = StreakWidgetModel.current()
        XCTAssertEqual(m.streak, 1)
        let goal = try XCTUnwrap(m.goal)
        XCTAssertTrue(goal.isDaily)
        XCTAssertEqual(goal.target, 5)
        XCTAssertEqual(goal.done, 2, "Zwei distinct geübte Wörter heute")
    }

    func testCurrentWithoutGoalHasNilGoal() {
        StreakStore.registerActivity()
        let m = StreakWidgetModel.current()
        XCTAssertEqual(m.streak, 1)
        XCTAssertNil(m.goal)
    }
}
