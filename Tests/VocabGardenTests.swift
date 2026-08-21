@testable import DailyHangul
import XCTest

/// Tests für die abgeleitete Garten-Darstellung (Issue #92). Rein wertbasiert –
/// keine SwiftData-/UI-Abhängigkeit nötig.
final class VocabGardenTests: XCTestCase {

    private func vocab(_ status: LearningStatus) -> Vocab {
        let v = Vocab(word: "가", meaning: "x")
        v.status = status
        return v
    }

    // MARK: - Zusammenfassung & Zähler

    func testCountsReflectStatusDistribution() {
        let garden = VocabGarden(vocabs: [vocab(.new), vocab(.learning), vocab(.learning), vocab(.learned)])
        XCTAssertEqual(garden.total, 4)
        XCTAssertEqual(garden.count(of: .new), 1)
        XCTAssertEqual(garden.count(of: .learning), 2)
        XCTAssertEqual(garden.count(of: .almostLearned), 0)
        XCTAssertEqual(garden.count(of: .learned), 1)
    }

    func testEmptyGardenIsNeitherBloomedNorSummarized() {
        let garden = VocabGarden(vocabs: [])
        XCTAssertFalse(garden.isFullyBloomed)
        XCTAssertFalse(garden.showsSummary)
    }

    func testFullyBloomedOnlyWhenAllLearned() {
        XCTAssertTrue(VocabGarden(vocabs: [vocab(.learned), vocab(.learned)]).isFullyBloomed)
        XCTAssertFalse(VocabGarden(vocabs: [vocab(.learned), vocab(.almostLearned)]).isFullyBloomed)
    }

    func testShowsSummaryAboveTileLimit() {
        let below = VocabGarden(vocabs: Array(repeating: vocab(.new), count: VocabGarden.tileLimit))
        XCTAssertFalse(below.showsSummary) // genau am Limit → noch Einzelpflanzen
        let above = VocabGarden(vocabs: Array(repeating: vocab(.new), count: VocabGarden.tileLimit + 1))
        XCTAssertTrue(above.showsSummary)
    }

    // MARK: - Pflanzen-Optik

    func testPlantEmojiUsesStageBelowLearned() {
        XCTAssertEqual(VocabGarden.plantEmoji(for: .new, groupHex: "#EF4444"), LearningStatus.new.gardenStageEmoji)
        XCTAssertEqual(VocabGarden.plantEmoji(for: .almostLearned, groupHex: "#EF4444"),
                       LearningStatus.almostLearned.gardenStageEmoji)
    }

    func testPlantEmojiUsesColoredBloomWhenLearned() {
        // „gelernt" → farbabhängige Blüte, nicht das Stufen-Fallback.
        XCTAssertEqual(VocabGarden.plantEmoji(for: .learned, groupHex: "#EF4444"),
                       VocabGarden.bloomEmoji(forHex: "#EF4444"))
    }

    func testBloomEmojiMapsHueBuckets() {
        XCTAssertEqual(VocabGarden.bloomEmoji(forHex: "#EF4444"), "🌷") // Rot
        XCTAssertEqual(VocabGarden.bloomEmoji(forHex: "#EAB308"), "🌻") // Gelb
        XCTAssertEqual(VocabGarden.bloomEmoji(forHex: "#22C55E"), "🌼") // Grün
        XCTAssertEqual(VocabGarden.bloomEmoji(forHex: "#06B6D4"), "🌸") // Cyan
        XCTAssertEqual(VocabGarden.bloomEmoji(forHex: "#3B82F6"), "🪻") // Blau
        XCTAssertEqual(VocabGarden.bloomEmoji(forHex: "#EC4899"), "🌺") // Pink
    }

    func testBloomEmojiFallsBackForGrayAndInvalid() {
        XCTAssertEqual(VocabGarden.bloomEmoji(forHex: "#78716C"), "🌼") // wenig gesättigt → Standardblüte
        XCTAssertEqual(VocabGarden.bloomEmoji(forHex: "not-a-color"), "🌼") // unparsebar → Standardblüte
    }
}
