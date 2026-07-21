@testable import DailyHangul
import XCTest

/// Prüft das Serialisieren/Parsen der gemerkten „Heute“-Auswahl (Richtung + Modi),
/// das in `ReviewSelection` gekapselt ist und von `ReviewSessionView` genutzt wird.
final class ReviewSelectionTests: XCTestCase {

    private let allModes = PracticeMode.allCases

    // MARK: - load

    func testLoadDefaultsToMixedAndAllModes() {
        // Leere gespeicherte Werte = Ausgangszustand: gemischt, leere Modi = alle.
        let selection = ReviewSelection.load(directionRaw: "", modesRaw: "", available: allModes)
        XCTAssertEqual(selection.direction, .mixed)
        XCTAssertTrue(selection.modes.isEmpty)
    }

    func testLoadParsesDirectionAndModes() {
        let selection = ReviewSelection.load(directionRaw: "wordToMeaning",
                                             modesRaw: "writing,multipleChoice",
                                             available: allModes)
        XCTAssertEqual(selection.direction, .wordToMeaning)
        XCTAssertEqual(selection.modes, [.writing, .multipleChoice])
    }

    func testLoadFallsBackToMixedForInvalidDirection() {
        let selection = ReviewSelection.load(directionRaw: "bogus", modesRaw: "", available: allModes)
        XCTAssertEqual(selection.direction, .mixed)
    }

    func testLoadDropsUnknownAndEmptyModeTokens() {
        let selection = ReviewSelection.load(directionRaw: "mixed",
                                             modesRaw: "writing,bogus,,listening",
                                             available: allModes)
        XCTAssertEqual(selection.modes, [.writing, .listening])
    }

    func testLoadFiltersUnavailableModes() {
        // Hören ist gespeichert, aber ohne koreanische Stimme nicht verfügbar → raus.
        let available = PracticeMode.available(hasVoice: false)
        let selection = ReviewSelection.load(directionRaw: "mixed",
                                             modesRaw: "listening,writing",
                                             available: available)
        XCTAssertEqual(selection.modes, [.writing])
    }

    // MARK: - modesRaw (Serialisierung)

    func testModesRawIsEmptyWhenAllModes() {
        XCTAssertEqual(ReviewSelection(direction: .mixed, modes: []).modesRaw, "")
    }

    func testModesRawIsStableRegardlessOfSetOrder() {
        let a = ReviewSelection(direction: .mixed, modes: [.writing, .multipleChoice]).modesRaw
        let b = ReviewSelection(direction: .mixed, modes: [.multipleChoice, .writing]).modesRaw
        XCTAssertEqual(a, b)
        XCTAssertEqual(a, "multipleChoice,writing")
    }

    // MARK: - Round-Trip

    func testRoundTripPreservesSelection() {
        let original = ReviewSelection(direction: .meaningToWord, modes: [.review, .writing])
        let restored = ReviewSelection.load(directionRaw: original.direction.rawValue,
                                            modesRaw: original.modesRaw,
                                            available: allModes)
        XCTAssertEqual(restored, original)
    }
}
