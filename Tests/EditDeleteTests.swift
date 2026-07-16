import XCTest
import SwiftData
@testable import DailyHangul

/// Prüft das Persistenz-Verhalten hinter den Bearbeiten-/Löschen-Funktionen
/// für Gruppen und Vokabeln (das, was GroupEditView/VocabEditView, GroupListView,
/// GroupDetailView und SearchView beim Speichern bzw. Löschen tun).
@MainActor
final class EditDeleteTests: XCTestCase {

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

    private func vocabCount() throws -> Int {
        try context.fetchCount(FetchDescriptor<Vocab>())
    }

    private func groupCount() throws -> Int {
        try context.fetchCount(FetchDescriptor<VocabGroup>())
    }

    // MARK: - Vokabel bearbeiten

    func testEditVocabUpdatesFields() throws {
        let group = VocabGroup(name: "Verben")
        context.insert(group)
        let vocab = Vocab(word: "가다", meaning: "gehen", group: group)
        context.insert(vocab)
        try context.save()

        // Wie VocabEditView.save: Felder überschreiben.
        vocab.word = "오다"
        vocab.meaning = "kommen"
        vocab.example = "집에 오다"
        try context.save()

        let fetched = try XCTUnwrap(
            try context.fetch(FetchDescriptor<Vocab>()).first
        )
        XCTAssertEqual(fetched.word, "오다")
        XCTAssertEqual(fetched.meaning, "kommen")
        XCTAssertEqual(fetched.example, "집에 오다")
    }

    func testEditVocabManualStatusPersists() throws {
        let vocab = Vocab(word: "가다", meaning: "gehen")
        context.insert(vocab)
        try context.save()

        vocab.setStatusManually(.learned)
        try context.save()

        let fetched = try XCTUnwrap(try context.fetch(FetchDescriptor<Vocab>()).first)
        XCTAssertEqual(fetched.status, .learned)
        XCTAssertEqual(fetched.successCounter, LearningStatus.masteredThreshold)
    }

    // MARK: - Vokabel löschen

    func testDeleteVocabRemovesItFromContextAndGroup() throws {
        let group = VocabGroup(name: "Essen")
        context.insert(group)
        let keep = Vocab(word: "밥", meaning: "Reis", group: group)
        let remove = Vocab(word: "물", meaning: "Wasser", group: group)
        context.insert(keep)
        context.insert(remove)
        try context.save()
        XCTAssertEqual(try vocabCount(), 2)

        // Wie GroupDetailView/SearchView.delete: einzelne Vokabel entfernen.
        context.delete(remove)
        try context.save()

        XCTAssertEqual(try vocabCount(), 1)
        let remaining = try context.fetch(FetchDescriptor<Vocab>())
        XCTAssertEqual(remaining.map(\.word), ["밥"])
        // Gruppe bleibt bestehen und enthält nur noch die behaltene Vokabel.
        XCTAssertEqual(group.vocabs.map(\.word), ["밥"])
    }

    // MARK: - Gruppe bearbeiten

    func testEditGroupUpdatesNameAndColor() throws {
        let group = VocabGroup(name: "Alt", colorHex: "#111111")
        context.insert(group)
        try context.save()

        // Wie GroupEditView.save.
        group.name = "Neu"
        group.colorHex = "#22CC88"
        try context.save()

        let fetched = try XCTUnwrap(try context.fetch(FetchDescriptor<VocabGroup>()).first)
        XCTAssertEqual(fetched.name, "Neu")
        XCTAssertEqual(fetched.colorHex, "#22CC88")
    }

    // MARK: - Gruppe löschen (Cascade)

    func testDeleteGroupCascadeDeletesItsVocabs() throws {
        let group = VocabGroup(name: "Wird gelöscht")
        context.insert(group)
        context.insert(Vocab(word: "하나", meaning: "eins", group: group))
        context.insert(Vocab(word: "둘", meaning: "zwei", group: group))
        try context.save()
        XCTAssertEqual(try groupCount(), 1)
        XCTAssertEqual(try vocabCount(), 2)

        // Wie GroupListView.delete: Löschen entfernt laut deleteRule .cascade
        // auch alle enthaltenen Vokabeln.
        context.delete(group)
        try context.save()

        XCTAssertEqual(try groupCount(), 0)
        XCTAssertEqual(try vocabCount(), 0)
    }

    func testDeleteGroupKeepsOtherGroupsVocabs() throws {
        let doomed = VocabGroup(name: "Weg")
        let survivor = VocabGroup(name: "Bleibt")
        context.insert(doomed)
        context.insert(survivor)
        context.insert(Vocab(word: "가", meaning: "a", group: doomed))
        context.insert(Vocab(word: "나", meaning: "b", group: survivor))
        try context.save()

        context.delete(doomed)
        try context.save()

        XCTAssertEqual(try groupCount(), 1)
        XCTAssertEqual(try vocabCount(), 1)
        let remaining = try XCTUnwrap(try context.fetch(FetchDescriptor<Vocab>()).first)
        XCTAssertEqual(remaining.word, "나")
        XCTAssertEqual(remaining.group?.name, "Bleibt")
    }
}
