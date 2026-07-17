import XCTest
import SwiftData
@testable import DailyHangul

/// Prüft die vollständige Sicherung/Wiederherstellung (`VocabBackup`): Round-Trip
/// aller Felder, id-erhaltende Idempotenz (keine Duplikate) und Merge-Verhalten.
@MainActor
final class VocabBackupTests: XCTestCase {

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

    private func makeSampleData() throws -> (VocabGroup, Vocab) {
        let group = VocabGroup(name: "Verben", colorHex: "#22CC88", sortOrder: 3)
        context.insert(group)
        let vocab = Vocab(word: "가다", meaning: "gehen", example: "학교에 가다", group: group)
        vocab.includeInWidget = true
        vocab.setStatusManually(.almostLearned)   // setzt statusRaw, counter, nextReviewAt
        vocab.timesPracticed = 5
        context.insert(vocab)
        try context.save()
        return (group, vocab)
    }

    /// export → decode → apply auf leeren Kontext stellt ALLE Felder wieder her.
    func testRoundTripRestoresAllFields() throws {
        let (group, vocab) = try makeSampleData()
        let data = try Data(contentsOf:
            VocabBackup.exportFile(groups: [group], vocabs: [vocab]))
        let backup = try VocabBackup.decode(data)

        // Frischer, leerer Store.
        let freshContainer = PersistenceController.makeContainer(inMemory: true)
        let freshContext = freshContainer.mainContext
        backup.apply(into: freshContext)

        let groups = try freshContext.fetch(FetchDescriptor<VocabGroup>())
        let vocabs = try freshContext.fetch(FetchDescriptor<Vocab>())
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(vocabs.count, 1)

        let g = try XCTUnwrap(groups.first)
        XCTAssertEqual(g.id, group.id)
        XCTAssertEqual(g.name, "Verben")
        XCTAssertEqual(g.colorHex, "#22CC88")
        XCTAssertEqual(g.sortOrder, 3)

        let v = try XCTUnwrap(vocabs.first)
        XCTAssertEqual(v.id, vocab.id)
        XCTAssertEqual(v.word, "가다")
        XCTAssertEqual(v.meaning, "gehen")
        XCTAssertEqual(v.example, "학교에 가다")
        XCTAssertTrue(v.includeInWidget)
        XCTAssertEqual(v.status, .almostLearned)
        XCTAssertEqual(v.successCounter, vocab.successCounter)
        XCTAssertEqual(v.timesPracticed, 5)
        // Datum via ISO8601 (ms-genau) → mit kleiner Toleranz vergleichen.
        let expectedDue = try XCTUnwrap(vocab.nextReviewAt).timeIntervalSinceReferenceDate
        let actualDue = try XCTUnwrap(v.nextReviewAt).timeIntervalSinceReferenceDate
        XCTAssertEqual(actualDue, expectedDue, accuracy: 0.01)
        // Beziehung über groupID rekonstruiert.
        XCTAssertEqual(v.group?.id, group.id)
    }

    /// Zweimaliges Anwenden derselben Sicherung erzeugt keine Duplikate (Upsert).
    func testApplyIsIdempotent() throws {
        let (group, vocab) = try makeSampleData()
        let backup = VocabBackup(from: [group], vocabs: [vocab])

        let freshContainer = PersistenceController.makeContainer(inMemory: true)
        let freshContext = freshContainer.mainContext
        backup.apply(into: freshContext)
        backup.apply(into: freshContext)   // erneut

        XCTAssertEqual(try freshContext.fetchCount(FetchDescriptor<VocabGroup>()), 1)
        XCTAssertEqual(try freshContext.fetchCount(FetchDescriptor<Vocab>()), 1)
    }

    /// Wiederherstellen aktualisiert vorhandene Objekte per id und fügt fehlende hinzu,
    /// ohne nicht enthaltene Objekte zu berühren.
    func testApplyMergesAndUpdatesById() throws {
        let (group, vocab) = try makeSampleData()

        // Sicherung mit geänderter Bedeutung + zusätzlicher Vokabel derselben Gruppe.
        var backup = VocabBackup(from: [group], vocabs: [vocab])
        backup.vocabs[0].meaning = "geändert"
        let extraID = UUID()
        backup.vocabs.append(VocabBackup.VocabDTO(
            id: extraID, word: "오다", meaning: "kommen", example: nil,
            statusRaw: 0, successCounter: 0, includeInWidget: false,
            timesPracticed: 0, lastPracticedAt: nil, nextReviewAt: nil,
            createdAt: .now, groupID: group.id))

        backup.apply(into: context)

        XCTAssertEqual(try groupCount(), 1)
        XCTAssertEqual(try vocabCount(), 2)   // kein Duplikat der vorhandenen Vokabel
        let updated = try XCTUnwrap(
            try context.fetch(FetchDescriptor<Vocab>()).first { $0.id == vocab.id })
        XCTAssertEqual(updated.meaning, "geändert")
        let added = try XCTUnwrap(
            try context.fetch(FetchDescriptor<Vocab>()).first { $0.id == extraID })
        XCTAssertEqual(added.group?.id, group.id)
    }
}
