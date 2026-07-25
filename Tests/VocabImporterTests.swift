@testable import DailyHangul
import SwiftData
import XCTest

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
        XCTAssertEqual(all.count, 1) // keine zweite Gruppe angelegt
        XCTAssertEqual(all.first?.vocabs.count, 2)
    }

    func testKeepsExistingMeaningOnDuplicate() throws {
        let existing = VocabGroup(name: "Berufe")
        context.insert(existing)
        context.insert(Vocab(word: "선생님", meaning: "Lehrer", group: existing))
        try context.save()

        // Gleiches Wort (mit Leerraum) andere Bedeutung → bestehende Bedeutung bleibt
        // erhalten (keine Lücke zu füllen) → übersprungen; „가수" ist neu.
        let result = VocabImporter.importRows(
            rows([(" 선생님 ", "Teacher"), ("가수", "Sänger")]),
            intoGroupNamed: "Berufe", context: context, existingGroups: try groups()
        )
        try context.save()

        XCTAssertEqual(result.added, 1)
        XCTAssertEqual(result.updated, 0)
        XCTAssertEqual(result.skipped, 1)
        XCTAssertEqual(try groups().first?.vocabs.count, 2) // keine zweite „선생님"
        let teacher = try groups().first?.vocabs.first { $0.word == "선생님" }
        XCTAssertEqual(teacher?.meaning, "Lehrer") // manuell gepflegte Bedeutung unberührt
    }

    func testSkipsIdenticalRowWithoutChange() throws {
        let existing = VocabGroup(name: "Berufe")
        context.insert(existing)
        context.insert(Vocab(word: "선생님", meaning: "Lehrer", group: existing))
        try context.save()

        let result = VocabImporter.importRows(
            rows([("선생님", "Lehrer")]),
            intoGroupNamed: "Berufe", context: context, existingGroups: try groups()
        )
        try context.save()

        XCTAssertEqual(result.added, 0)
        XCTAssertEqual(result.updated, 0)
        XCTAssertEqual(result.skipped, 1) // nichts geändert → übersprungen
    }

    func testReimportAddsTopikAndPreservesProgress() throws {
        let existing = VocabGroup(name: "Berufe")
        context.insert(existing)
        let teacher = Vocab(word: "선생님", meaning: "Lehrer", group: existing)
        teacher.registerResult(correct: true) // Lernfortschritt aufbauen
        let counterBefore = teacher.successCounter
        context.insert(teacher)
        try context.save()

        // Erneuter Import mit TOPIK-Spalte reichert die bestehende Vokabel an.
        let result = VocabImporter.importRows(
            [VocabCSV.Row(word: "선생님", meaning: "Lehrer", example: nil, topik: .one)],
            intoGroupNamed: "Berufe", context: context, existingGroups: try groups()
        )
        try context.save()

        XCTAssertEqual(result.updated, 1)
        XCTAssertEqual(teacher.topikLevel, .one)
        XCTAssertEqual(teacher.successCounter, counterBefore) // Fortschritt unangetastet
        XCTAssertGreaterThan(counterBefore, 0)
    }

    func testEmptyFieldsDoNotClearExistingValues() throws {
        let existing = VocabGroup(name: "Berufe")
        context.insert(existing)
        let teacher = Vocab(word: "선생님", meaning: "Lehrer", example: "가르치다",
                            topik: .two, group: existing)
        context.insert(teacher)
        try context.save()

        // Zeile ohne Beispiel/TOPIK darf gepflegte Werte nicht löschen → keine Änderung.
        let result = VocabImporter.importRows(
            rows([("선생님", "Lehrer")]),
            intoGroupNamed: "Berufe", context: context, existingGroups: try groups()
        )
        try context.save()

        XCTAssertEqual(result.skipped, 1)
        XCTAssertEqual(result.updated, 0)
        XCTAssertEqual(teacher.example, "가르치다")
        XCTAssertEqual(teacher.topikLevel, .two)
    }

    func testKeepsFirstMeaningForDuplicatesWithinSameImport() throws {
        let result = VocabImporter.importRows(
            rows([("밥", "Reis"), ("밥", "Mahlzeit")]),
            intoGroupNamed: "Essen", context: context, existingGroups: try groups()
        )
        try context.save()

        XCTAssertEqual(result.added, 1)
        XCTAssertEqual(result.updated, 0) // zweite Zeile überschreibt die erste nicht
        XCTAssertEqual(result.skipped, 1)
        XCTAssertEqual(try groups().first?.vocabs.count, 1)
        XCTAssertEqual(try groups().first?.vocabs.first?.meaning, "Reis")
    }

    func testCarriesTopikLevelIntoVocab() throws {
        let rows = [
            VocabCSV.Row(word: "선생님", meaning: "Lehrer", example: nil, topik: .one),
            VocabCSV.Row(word: "교수", meaning: "Professor", example: nil, topik: .two),
            VocabCSV.Row(word: "가수", meaning: "Sänger", example: nil) // ohne Niveau
        ]
        VocabImporter.importRows(rows, intoGroupNamed: "Berufe", context: context, existingGroups: try groups())
        try context.save()

        let byWord = Dictionary(uniqueKeysWithValues:
            (try groups().first?.vocabs ?? []).map { ($0.word, $0.topikLevel) })
        XCTAssertEqual(byWord["선생님"], .one)
        XCTAssertEqual(byWord["교수"], .two)
        XCTAssertNil(byWord["가수"] ?? nil) // ungetaggt bleibt nil
    }

    /// Beim Import mehrerer Pakete in einem Rutsch (statische `existingGroups`-Liste)
    /// muss jede neu angelegte Gruppe eine eigene, aufsteigende `sortOrder` bekommen.
    func testAssignsDistinctSortOrderAcrossMultipleImports() throws {
        let snapshot = try groups() // einmalig, wie im "Alle importieren"-Aufruf
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
