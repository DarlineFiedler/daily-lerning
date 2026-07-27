@testable import DailyHangul
import SwiftData
import XCTest

/// Prüft das Mehrfach-Verschieben von Vokabeln zwischen Gruppen (das, was
/// `GroupDetailView.move(_:to:)` beim Speichern tut): Zielgruppe wechselt, Quelle
/// verliert die Wörter, Lernstand bleibt unverändert.
@MainActor
final class MoveVocabTests: XCTestCase {

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

    /// Wie `GroupDetailView.move`: die Gruppenzugehörigkeit der Wörter umsetzen.
    private func move(_ vocabs: [Vocab], to target: VocabGroup) throws {
        for vocab in vocabs { vocab.group = target }
        try context.save()
    }

    func testMovingVocabsSwitchesGroupMembership() throws {
        let source = VocabGroup(name: "Quelle")
        let target = VocabGroup(name: "Ziel")
        context.insert(source)
        context.insert(target)
        let a = Vocab(word: "가다", meaning: "gehen", group: source)
        let b = Vocab(word: "오다", meaning: "kommen", group: source)
        let stay = Vocab(word: "먹다", meaning: "essen", group: source)
        context.insert(a)
        context.insert(b)
        context.insert(stay)
        try context.save()

        try move([a, b], to: target)

        XCTAssertEqual(Set(target.vocabs.map(\.word)), ["가다", "오다"])
        XCTAssertEqual(source.vocabs.map(\.word), ["먹다"])
        XCTAssertEqual(a.group?.id, target.id)
        XCTAssertEqual(b.group?.id, target.id)
    }

    func testMovingKeepsLearningProgressUnchanged() throws {
        let source = VocabGroup(name: "Quelle")
        let target = VocabGroup(name: "Ziel")
        context.insert(source)
        context.insert(target)
        let vocab = Vocab(word: "가다", meaning: "gehen", group: source)
        vocab.setStatusManually(.almostLearned)
        vocab.includeInWidget = true
        vocab.timesPracticed = 7
        context.insert(vocab)
        try context.save()

        let statusBefore = vocab.status
        let counterBefore = vocab.successCounter
        let dueBefore = vocab.nextReviewAt

        try move([vocab], to: target)

        XCTAssertEqual(vocab.group?.id, target.id)
        XCTAssertEqual(vocab.status, statusBefore)
        XCTAssertEqual(vocab.successCounter, counterBefore)
        XCTAssertEqual(vocab.nextReviewAt, dueBefore)
        XCTAssertTrue(vocab.includeInWidget)
        XCTAssertEqual(vocab.timesPracticed, 7)
    }
}
