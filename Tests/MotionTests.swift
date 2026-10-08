@testable import DailyHangul
import SwiftUI
import XCTest

/// Tests für die zentrale Reduce-Motion-Hilfe (Issue #120): bei aktivem
/// Reduce-Motion darf keine Animation durchgereicht werden.
final class MotionTests: XCTestCase {

    func testReturnsNilWhenReduceMotionOn() {
        XCTAssertNil(Motion.animation(.spring(response: 0.5, dampingFraction: 0.6), reduceMotion: true))
    }

    func testReturnsAnimationWhenReduceMotionOff() {
        XCTAssertNotNil(Motion.animation(.spring(response: 0.5, dampingFraction: 0.6), reduceMotion: false))
    }

    func testPassesThroughGivenAnimationUnchanged() {
        let anim = Animation.easeInOut(duration: 0.25)
        XCTAssertEqual(Motion.animation(anim, reduceMotion: false), anim)
    }
}
