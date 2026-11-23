@testable import DailyHangul
import SwiftData
import XCTest

/// Prüft die gemeinsamen Beherrschungs-Werte einer Gruppe (#144), die Mastery-,
/// Gruppen- und Garten-Ansicht statt eigener Kopien verwenden.
@MainActor
final class VocabGroupMasteryTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUp() {
        super.setUp()
        container = PersistenceController.makeContainer(inMemory: true)
        context = container.mainContext
    }

    override func tearDown() {
        context = nil
        container = nil
        super.tearDown()
    }

    private func makeGroup(statuses: [LearningStatus]) -> VocabGroup {
        let group = VocabGroup(name: "Testbeet")
        context.insert(group)
        for (index, status) in statuses.enumerated() {
            let vocab = Vocab(word: "단어\(index)", meaning: "Wort \(index)", group: group)
            vocab.status = status
            context.insert(vocab)
        }
        return group
    }

    func testEmptyGroupHasZeroMastery() {
        let group = makeGroup(statuses: [])
        XCTAssertEqual(group.learnedCount, 0)
        XCTAssertEqual(group.masteryFraction, 0)
    }

    func testPartiallyLearnedGroup() {
        let group = makeGroup(statuses: [.learned, .new, .learning, .learned])
        XCTAssertEqual(group.learnedCount, 2)
        XCTAssertEqual(group.masteryFraction, 0.5, accuracy: 0.0001)
    }

    func testFullyLearnedGroup() {
        let group = makeGroup(statuses: [.learned, .learned, .learned])
        XCTAssertEqual(group.learnedCount, 3)
        XCTAssertEqual(group.masteryFraction, 1)
    }
}
