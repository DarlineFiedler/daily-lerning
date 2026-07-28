@testable import DailyHangul
import XCTest

final class DeepLinkTests: XCTestCase {

    func testRoundTrip() {
        let id = UUID()
        let url = DeepLink.wordURL(id: id)
        XCTAssertEqual(DeepLink.wordID(from: url), id)
    }

    func testRejectsWrongScheme() {
        let url = URL(string: "https://word/\(UUID().uuidString)")!
        XCTAssertNil(DeepLink.wordID(from: url))
    }

    func testRejectsWrongHost() {
        let url = URL(string: "dailyhangul://group/\(UUID().uuidString)")!
        XCTAssertNil(DeepLink.wordID(from: url))
    }

    func testRejectsNonUUIDPath() {
        let url = URL(string: "dailyhangul://word/not-a-uuid")!
        XCTAssertNil(DeepLink.wordID(from: url))
    }

    func testSessionURLRoundTrip() {
        XCTAssertTrue(DeepLink.isSession(DeepLink.sessionURL))
    }

    func testIsSessionRejectsOtherHosts() {
        XCTAssertFalse(DeepLink.isSession(DeepLink.reviewURL))
        XCTAssertFalse(DeepLink.isSession(URL(string: "https://session")!))
    }

    func testStreakURLRoundTrip() {
        XCTAssertTrue(DeepLink.isStreak(DeepLink.streakURL))
    }

    func testIsStreakRejectsOtherHosts() {
        XCTAssertFalse(DeepLink.isStreak(DeepLink.reviewURL))
        XCTAssertFalse(DeepLink.isStreak(DeepLink.sessionURL))
        XCTAssertFalse(DeepLink.isStreak(URL(string: "https://streak")!))
    }
}
