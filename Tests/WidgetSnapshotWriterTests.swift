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
    private func insert(_ word: String, meaning: String, includeInWidget: Bool) -> Vocab {
        let vocab = Vocab(word: word, meaning: meaning)
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
}
