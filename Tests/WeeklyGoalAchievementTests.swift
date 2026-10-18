@testable import DailyHangul
import SwiftData
import XCTest

/// Regressionstest für das „Wochenziel erreicht"-Badge (🏁). Die Flag `weeklyGoalReached`
/// wurde früher nie gesetzt → das Badge (und damit das 100%-Meta-Badge) war dauerhaft
/// unerreichbar. Prüft, dass `AchievementService` das erreichte Wochenziel erkennt und
/// verbucht. Schreibt in `AppGroup.defaults`; die betroffenen Keys werden je Test gesichert
/// und wiederhergestellt.
@MainActor
final class WeeklyGoalAchievementTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    private static let keys = [
        AchievementKeys.unlockedIDs, AchievementKeys.unlockDates, AchievementKeys.progress,
        GoalKeys.weekly, GoalKeys.metric, WeeklyReviewKeys.log
    ]
    private var saved: [String: Any?] = [:]

    override func setUp() {
        super.setUp()
        container = PersistenceController.makeContainer(inMemory: true)
        context = container.mainContext
        let d = AppGroup.defaults
        for key in Self.keys {
            saved[key] = d.object(forKey: key)
            d.removeObject(forKey: key)
        }
    }

    override func tearDown() {
        let d = AppGroup.defaults
        for key in Self.keys {
            if let value = saved[key], let value { d.set(value, forKey: key) } else { d.removeObject(forKey: key) }
        }
        saved = [:]
        context = nil
        container = nil
        super.tearDown()
    }

    /// Ohne gesetztes Ziel gilt es nie als erreicht.
    func testNoGoalMeansNotReached() {
        XCTAssertFalse(AchievementService.isWeeklyGoalReached())
    }

    /// Erreichtes Wochenziel schaltet das Badge frei.
    func testWeeklyGoalReachedUnlocksBadge() {
        let d = AppGroup.defaults
        d.set(3, forKey: GoalKeys.weekly)
        d.set(GoalMetric.practiced.rawValue, forKey: GoalKeys.metric)
        for _ in 0 ..< 3 {
            WeeklyReviewStore.record(wordID: UUID(), becameLearned: false, correct: true)
        }

        XCTAssertTrue(AchievementService.isWeeklyGoalReached())
        AchievementService.checkWeeklyGoalReached(context: context)
        XCTAssertTrue(AchievementStore.unlockedIDs.contains("weeklyGoal"),
                      "Das Wochenziel-Badge muss nach Erreichen des Ziels freigeschaltet sein.")
    }

    /// Unter dem Ziel bleibt das Badge gesperrt.
    func testBelowGoalStaysLocked() {
        let d = AppGroup.defaults
        d.set(5, forKey: GoalKeys.weekly)
        d.set(GoalMetric.practiced.rawValue, forKey: GoalKeys.metric)
        for _ in 0 ..< 2 {
            WeeklyReviewStore.record(wordID: UUID(), becameLearned: false, correct: true)
        }

        XCTAssertFalse(AchievementService.isWeeklyGoalReached())
        AchievementService.checkWeeklyGoalReached(context: context)
        XCTAssertFalse(AchievementStore.unlockedIDs.contains("weeklyGoal"))
    }
}
