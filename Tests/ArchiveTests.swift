@testable import DailyHangul
import SwiftData
import XCTest

/// Prüft die Kern-Filterregel des Archivierens: archivierte Gruppen (und ihre
/// Vokabeln) fallen aus der Session-Auswahl und den aktiven Dashboard-Werten,
/// bleiben aber als Daten erhalten. Spiegelt, was `PracticeConfigView`
/// (`activeGroups`/`resolvedGroups`/`pool`) und `HomeView` (`activeVocabs`) tun.
@MainActor
final class ArchiveTests: XCTestCase {

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

    /// Legt eine aktive und eine archivierte Gruppe mit je einem Wort an.
    private func makeGroups() throws -> (active: VocabGroup, archived: VocabGroup) {
        let active = VocabGroup(name: "Aktiv")
        let archived = VocabGroup(name: "Archiv", isArchived: true)
        context.insert(active)
        context.insert(archived)
        context.insert(Vocab(word: "가다", meaning: "gehen", group: active))
        context.insert(Vocab(word: "오다", meaning: "kommen", group: archived))
        try context.save()
        return (active, archived)
    }

    /// Archivieren löscht nichts: beide Gruppen und beide Wörter bleiben im Store.
    func testArchivingKeepsData() throws {
        _ = try makeGroups()
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<VocabGroup>()), 2)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Vocab>()), 2)
    }

    /// Die Gruppenauswahl fürs Üben (`allGroups.filter { !$0.isArchived }`) enthält
    /// nur aktive Gruppen.
    func testSessionGroupSelectionExcludesArchived() throws {
        let (active, _) = try makeGroups()
        let allGroups = try context.fetch(FetchDescriptor<VocabGroup>())

        let activeGroups = allGroups.filter { !$0.isArchived }

        XCTAssertEqual(activeGroups.map(\.id), [active.id])
    }

    /// Der Session-Wortpool (`resolvedGroups.flatMap(\.vocabs)`) enthält keine Wörter
    /// aus archivierten Gruppen.
    func testSessionPoolExcludesArchivedWords() throws {
        _ = try makeGroups()
        let allGroups = try context.fetch(FetchDescriptor<VocabGroup>())

        let pool = allGroups.filter { !$0.isArchived }.flatMap(\.vocabs)

        XCTAssertEqual(pool.map(\.word), ["가다"])
    }

    /// Die aktiven Dashboard-Wörter (`vocabs.filter { $0.group?.isArchived != true }`)
    /// blenden Wörter archivierter Gruppen aus.
    func testActiveVocabsExcludeArchivedGroups() throws {
        _ = try makeGroups()
        let allVocabs = try context.fetch(FetchDescriptor<Vocab>())

        let activeVocabs = allVocabs.filter { $0.group?.isArchived != true }

        XCTAssertEqual(activeVocabs.map(\.word), ["가다"])
    }

    /// Reaktivieren bringt eine Gruppe zurück in die aktive Auswahl.
    func testReactivatingRestoresGroup() throws {
        let (_, archived) = try makeGroups()

        archived.isArchived = false
        try context.save()

        let activeGroups = try context.fetch(FetchDescriptor<VocabGroup>())
            .filter { !$0.isArchived }
        XCTAssertEqual(Set(activeGroups.map(\.name)), ["Aktiv", "Archiv"])
    }
}
