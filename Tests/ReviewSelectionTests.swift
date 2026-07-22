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

    // MARK: - Wortanzahl (wordLimit)

    func testLoadDefaultsToNilWordLimit() {
        // Kein gespeicherter Wert (0) = keine Begrenzung.
        let selection = ReviewSelection.load(directionRaw: "", modesRaw: "", available: allModes)
        XCTAssertNil(selection.wordLimit)
    }

    func testLoadParsesWordLimit() {
        let selection = ReviewSelection.load(directionRaw: "mixed", modesRaw: "",
                                             wordLimitRaw: 20, available: allModes)
        XCTAssertEqual(selection.wordLimit, 20)
    }

    func testLoadTreatsNonPositiveWordLimitAsAll() {
        for raw in [0, -1] {
            let selection = ReviewSelection.load(directionRaw: "mixed", modesRaw: "",
                                                 wordLimitRaw: raw, available: allModes)
            XCTAssertNil(selection.wordLimit)
        }
    }

    func testWordLimitRawIsZeroWhenNil() {
        XCTAssertEqual(ReviewSelection(direction: .mixed, modes: [], wordLimit: nil).wordLimitRaw, 0)
    }

    // MARK: - effectiveCount (Begrenzung vs. Pool)

    func testEffectiveCountUsesFullPoolWhenNoLimit() {
        let selection = ReviewSelection(direction: .mixed, modes: [], wordLimit: nil)
        XCTAssertEqual(selection.effectiveCount(poolCount: 30), 30)
    }

    func testEffectiveCountCapsToWordLimit() {
        let selection = ReviewSelection(direction: .mixed, modes: [], wordLimit: 10)
        XCTAssertEqual(selection.effectiveCount(poolCount: 30), 10)
    }

    func testEffectiveCountClampsToPoolWhenLimitExceedsPool() {
        // 50 gewählt, aber nur 12 fällig → 12 (Start-Bar darf nicht überzeichnen).
        let selection = ReviewSelection(direction: .mixed, modes: [], wordLimit: 50)
        XCTAssertEqual(selection.effectiveCount(poolCount: 12), 12)
    }

    func testEffectiveCountIsZeroForEmptyPool() {
        let selection = ReviewSelection(direction: .mixed, modes: [], wordLimit: 10)
        XCTAssertEqual(selection.effectiveCount(poolCount: 0), 0)
    }

    // MARK: - Round-Trip

    func testRoundTripPreservesSelection() {
        let original = ReviewSelection(direction: .meaningToWord, modes: [.review, .writing],
                                       wordLimit: 10)
        let restored = ReviewSelection.load(directionRaw: original.direction.rawValue,
                                            modesRaw: original.modesRaw,
                                            wordLimitRaw: original.wordLimitRaw,
                                            available: allModes)
        XCTAssertEqual(restored, original)
    }
}
