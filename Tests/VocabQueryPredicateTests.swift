@testable import DailyHangul
import SwiftData
import XCTest

/// Sichert die @Query-Optimierungen aus Issue #141 ab: das `Vocab.notNewPredicate`
/// (Attribut-Filter statt Voll-Fetch) und die Invariante, auf der die RootView-Tab-Leiste
/// beruht – neue Wörter dürfen den Fälligkeits-Count nicht beeinflussen.
@MainActor
final class VocabQueryPredicateTests: XCTestCase {

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

    /// Gemischter Datensatz: je ein Wort pro Status, eines heute geübt, plus ein gelerntes
    /// Wort in einer archivierten Gruppe.
    private func makeMixed() throws {
        let active = VocabGroup(name: "Aktiv")
        let archived = VocabGroup(name: "Archiv", isArchived: true)
        context.insert(active)
        context.insert(archived)

        let new = Vocab(word: "neu", meaning: "-", group: active) // bleibt .new
        context.insert(new)

        let learning = Vocab(word: "lernend", meaning: "-", group: active)
        learning.setStatusManually(.learning)
        context.insert(learning)

        let almost = Vocab(word: "fast", meaning: "-", group: active)
        almost.setStatusManually(.almostLearned)
        context.insert(almost)

        let learned = Vocab(word: "gelernt", meaning: "-", group: active)
        learned.setStatusManually(.learned)
        context.insert(learned)

        let doneToday = Vocab(word: "heute", meaning: "-", group: active)
        doneToday.setStatusManually(.learning)
        doneToday.lastPracticedAt = .now // heute schon bearbeitet → nicht mehr offen
        context.insert(doneToday)

        let archivedLearned = Vocab(word: "archiviert", meaning: "-", group: archived)
        archivedLearned.setStatusManually(.learned)
        context.insert(archivedLearned)

        try context.save()
    }

    /// `notNewPredicate` liefert genau die Nicht-neuen Wörter – inkl. archivierter, da das
    /// Prädikat bewusst NICHT nach Archiv filtert (group-Traversierung im #Predicate heikel).
    func testNotNewPredicateExcludesOnlyNew() throws {
        try makeMixed()
        let nonNew = try context.fetch(FetchDescriptor<Vocab>(predicate: Vocab.notNewPredicate))

        XCTAssertEqual(Set(nonNew.map(\.word)),
                       ["lernend", "fast", "gelernt", "heute", "archiviert"])
        XCTAssertFalse(nonNew.contains { $0.status == .new })
    }

    /// RootView-Invariante: Das Vorfiltern neuer Wörter (via `notNewPredicate`) ändert den
    /// `DailyPlan.openWordCount` nicht – neue Wörter zählen dort ohnehin nie mit.
    func testOpenWordCountUnaffectedByDroppingNewWords() throws {
        try makeMixed()
        let all = try context.fetch(FetchDescriptor<Vocab>())
        let active = all.filter { $0.group?.isArchived != true } // bisheriges Verhalten
        let nonNewActive = active.filter { $0.status != .new } // nach der Optimierung

        XCTAssertEqual(DailyPlan.openWordCount(from: active),
                       DailyPlan.openWordCount(from: nonNewActive))
        // Sanity: lernend + fast + gelernt offen, "heute" erledigt, "neu" zählt nicht → 3.
        XCTAssertEqual(DailyPlan.openWordCount(from: active), 3)
    }
}
