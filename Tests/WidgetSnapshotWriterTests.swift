@testable import DailyHangul
import SwiftData
import XCTest

/// Prüft die Wortauswahl fürs Widget (`WidgetSnapshotWriter.widgetWords`):
/// bevorzugt markierte Wörter, fällt sonst auf den gesamten Wortschatz zurück.
@MainActor
final class WidgetSnapshotWriterTests: XCTestCase {

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

    @discardableResult
    private func insert(_ word: String, meaning: String, includeInWidget: Bool,
                        group: VocabGroup? = nil) -> Vocab {
        let vocab = Vocab(word: word, meaning: meaning, group: group)
        vocab.includeInWidget = includeInWidget
        context.insert(vocab)
        return vocab
    }

    /// Sind Wörter markiert, enthält das Widget genau diese – die nicht markierten
    /// bleiben außen vor.
    func testUsesOnlyStarredWordsWhenPresent() throws {
        insert("가다", meaning: "gehen", includeInWidget: true)
        insert("오다", meaning: "kommen", includeInWidget: false)
        try context.save()

        let words = WidgetSnapshotWriter.widgetWords(context: context)
        XCTAssertEqual(words.map(\.word), ["가다"])
    }

    /// Ist kein Wort markiert, fällt es auf den gesamten Wortschatz zurück
    /// (statt „No words").
    func testFallsBackToAllWordsWhenNoneStarred() throws {
        insert("가다", meaning: "gehen", includeInWidget: false)
        insert("오다", meaning: "kommen", includeInWidget: false)
        try context.save()

        let words = WidgetSnapshotWriter.widgetWords(context: context)
        XCTAssertEqual(Set(words.map(\.word)), ["가다", "오다"])
    }

    /// Gibt es überhaupt keine Vokabeln, bleibt die Wortliste leer
    /// (das Widget zeigt dann seinen echten Leerzustand).
    func testEmptyWhenNoVocabExists() {
        let words = WidgetSnapshotWriter.widgetWords(context: context)
        XCTAssertTrue(words.isEmpty)
    }

    /// Markierte Wörter aus einer archivierten Gruppe gehören NICHT aufs Widget –
    /// die Gruppe ist pausiert.
    func testExcludesStarredWordsFromArchivedGroups() throws {
        let active = VocabGroup(name: "Aktiv")
        let archived = VocabGroup(name: "Archiv", isArchived: true)
        context.insert(active)
        context.insert(archived)
        insert("가다", meaning: "gehen", includeInWidget: true, group: active)
        insert("오다", meaning: "kommen", includeInWidget: true, group: archived)
        try context.save()

        let words = WidgetSnapshotWriter.widgetWords(context: context)
        XCTAssertEqual(words.map(\.word), ["가다"])
    }

    /// Auch im Fallback (kein Wort markiert) bleiben archivierte Gruppen außen vor.
    func testFallbackExcludesArchivedGroups() throws {
        let active = VocabGroup(name: "Aktiv")
        let archived = VocabGroup(name: "Archiv", isArchived: true)
        context.insert(active)
        context.insert(archived)
        insert("가다", meaning: "gehen", includeInWidget: false, group: active)
        insert("오다", meaning: "kommen", includeInWidget: false, group: archived)
        try context.save()

        let words = WidgetSnapshotWriter.widgetWords(context: context)
        XCTAssertEqual(words.map(\.word), ["가다"])
    }

    /// Zweimal derselbe Inhalt: Der erste Refresh schreibt, der zweite (identische)
    /// wird als redundant übersprungen (kein Datei-Write / Widget-Reload).
    /// Eindeutige Wörter je Test halten die prozess-lokale Change-Detection deterministisch.
    func testSkipsRedundantRefreshWithUnchangedContent() {
        let vocabs = [insert("스킵테스트가", meaning: "a", includeInWidget: false)]

        XCTAssertTrue(WidgetSnapshotWriter.refresh(activeVocabs: vocabs),
                      "Neuer Inhalt muss geschrieben werden")
        XCTAssertFalse(WidgetSnapshotWriter.refresh(activeVocabs: vocabs),
                       "Unveränderter Inhalt darf nicht erneut geschrieben werden")
    }

    /// Ändert sich die Wortauswahl (hier: Stern-Toggle), schreibt der nächste Refresh
    /// wieder – die Change-Detection verschluckt echte Änderungen nicht.
    func testWritesAgainWhenContentChanges() {
        let a = insert("스킵테스트나", meaning: "a", includeInWidget: false)
        let b = insert("스킵테스트다", meaning: "b", includeInWidget: false)
        let vocabs = [a, b]

        XCTAssertTrue(WidgetSnapshotWriter.refresh(activeVocabs: vocabs))
        XCTAssertFalse(WidgetSnapshotWriter.refresh(activeVocabs: vocabs))

        // Stern auf b → Auswahl schrumpft von [a, b] auf [b].
        b.includeInWidget = true
        XCTAssertTrue(WidgetSnapshotWriter.refresh(activeVocabs: vocabs),
                      "Geänderte Wortauswahl muss erneut geschrieben werden")
    }
}
