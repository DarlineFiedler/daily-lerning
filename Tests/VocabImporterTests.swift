import XCTest
import SwiftData
@testable import DailyHangul

/// Prüft die zentrale Import-Logik (`VocabImporter`): Gruppen-Anlage/-Wiederverwendung
/// und Dubletten-Erkennung anhand des koreanischen Worts.
@MainActor
final class VocabImporterTests: XCTestCase {

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

    private func groups() throws -> [VocabGroup] {
        try context.fetch(FetchDescriptor<VocabGroup>())
    }

    private func rows(_ pairs: [(String, String)]) -> [VocabCSV.Row] {
        pairs.map { VocabCSV.Row(word: $0.0, meaning: $0.1, example: nil) }
    }

    func testCreatesNewGroupWhenNoneExists() throws {
        let result = VocabImporter.importRows(
            rows([("선생님", "Lehrer"), ("가수", "Sänger")]),
            intoGroupNamed: "Berufe", context: context, existingGroups: try groups()
        )
        try context.save()

        XCTAssertEqual(result.added, 2)
        XCTAssertEqual(result.skipped, 0)
        let all = try groups()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.name, "Berufe")
        XCTAssertEqual(all.first?.vocabs.count, 2)
    }

    func testAddsIntoExistingGroupCaseInsensitive() throws {
        let existing = VocabGroup(name: "Berufe")
        context.insert(existing)
        context.insert(Vocab(word: "선생님", meaning: "Lehrer", group: existing))
        try context.save()

        let result = VocabImporter.importRows(
            rows([("가수", "Sänger")]),
            intoGroupNamed: "berufe", context: context, existingGroups: try groups()
        )
        try context.save()

        XCTAssertEqual(result.added, 1)
        let all = try groups()
        XCTAssertEqual(all.count, 1)                 // keine zweite Gruppe angelegt
        XCTAssertEqual(all.first?.vocabs.count, 2)
    }

    func testSkipsDuplicateWordNormalized() throws {
        let existing = VocabGroup(name: "Berufe")
        context.insert(existing)
        context.insert(Vocab(word: "선생님", meaning: "Lehrer", group: existing))
        try context.save()

        // Gleiches Wort (mit Leerraum) andere Bedeutung → übersprungen; „가수" ist neu.
        let result = VocabImporter.importRows(
            rows([(" 선생님 ", "Teacher"), ("가수", "Sänger")]),
            intoGroupNamed: "Berufe", context: context, existingGroups: try groups()
        )
        try context.save()

        XCTAssertEqual(result.added, 1)
        XCTAssertEqual(result.skipped, 1)
        XCTAssertEqual(try groups().first?.vocabs.count, 2)
    }

    func testSkipsDuplicatesWithinSameImport() throws {
        let result = VocabImporter.importRows(
            rows([("밥", "Reis"), ("밥", "Mahlzeit")]),
            intoGroupNamed: "Essen", context: context, existingGroups: try groups()
        )
        try context.save()

        XCTAssertEqual(result.added, 1)
        XCTAssertEqual(result.skipped, 1)
    }

    /// Beim Import mehrerer Pakete in einem Rutsch (statische `existingGroups`-Liste)
    /// muss jede neu angelegte Gruppe eine eigene, aufsteigende `sortOrder` bekommen.
    func testAssignsDistinctSortOrderAcrossMultipleImports() throws {
        let snapshot = try groups()   // einmalig, wie im "Alle importieren"-Aufruf
        VocabImporter.importRows(rows([("가다", "gehen")]),
                                 intoGroupNamed: "Verben", context: context, existingGroups: snapshot)
        VocabImporter.importRows(rows([("사과", "Apfel")]),
                                 intoGroupNamed: "Essen", context: context, existingGroups: snapshot)
        VocabImporter.importRows(rows([("선생님", "Lehrer")]),
                                 intoGroupNamed: "Berufe", context: context, existingGroups: snapshot)
        try context.save()

        let orders = try groups().map(\.sortOrder).sorted()
        XCTAssertEqual(orders, [0, 1, 2], "Jede neue Gruppe braucht eine eindeutige sortOrder")
    }
}
