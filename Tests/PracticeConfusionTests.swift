@testable import DailyHangul
import SwiftData
import XCTest

/// Prüft den „Verwechslungs"-Hinweis des Schreib-Modus: hat man statt des gesuchten
/// ein anderes bekanntes Wort getippt, findet `PracticeItem.confusedPair(forTyped:)`
/// dessen Paar (siehe `WritingView`).
@MainActor
final class PracticeConfusionTests: XCTestCase {

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

    /// Fügt zwei Länder-Karten ein und baut daraus eine Schreib-Session in der gegebenen
    /// Richtung. Gibt Session plus das Item der Deutschland-Karte zurück.
    private func makeSession(direction: PracticeDirection)
        throws -> (session: PracticeSession, germanyItem: PracticeItem) {
        let germany = Vocab(word: "독일", meaning: "Deutschland")
        let japan = Vocab(word: "일본", meaning: "Japan")
        context.insert(germany)
        context.insert(japan)
        let all = [germany, japan]
        let session = PracticeSession(
            vocabs: all, distractorPool: all,
            config: PracticeConfig(direction: direction, modes: [.writing]), context: context
        )
        let item = try XCTUnwrap(session.items.first { $0.vocab.id == germany.id })
        return (session, item)
    }

    /// Bei einer Schreib-Session trägt jedes Item den vollen Wortschatz als Paare, damit
    /// eine Verwechslung erkannt werden kann.
    func testConfusablesPopulatedForWritingSession() throws {
        let (session, _) = try makeSession(direction: .meaningToWord)
        let item = try XCTUnwrap(session.items.first)
        XCTAssertEqual(Set(item.confusables), [WordPair(word: "독일", meaning: "Deutschland"),
                                               WordPair(word: "일본", meaning: "Japan")])
    }

    /// Ohne Schreib-Modus bleibt die (nur dort genutzte) Verwechslungs-Liste leer.
    func testConfusablesEmptyWithoutWritingMode() {
        let vocabs = (0 ..< 3).map { i -> Vocab in
            let v = Vocab(word: "단어\(i)", meaning: "Wort \(i)")
            context.insert(v)
            return v
        }
        let session = PracticeSession(
            vocabs: vocabs, distractorPool: vocabs,
            config: PracticeConfig(modes: [.review]), context: context
        )
        XCTAssertTrue(session.items.allSatisfy { $0.confusables.isEmpty })
    }

    /// Bedeutung→Wort: Tippt man statt des gesuchten Worts ein anderes bekanntes Wort,
    /// wird dessen Paar für den Hinweis gefunden.
    func testConfusedPairMeaningToWord() throws {
        let (_, item) = try makeSession(direction: .meaningToWord)
        XCTAssertEqual(item.confusedPair(forTyped: "일본"),
                       WordPair(word: "일본", meaning: "Japan"))
        // Die gesuchte Lösung selbst ist keine Verwechslung.
        XCTAssertNil(item.confusedPair(forTyped: "독일"))
        // Unbekannte Eingabe ⇒ kein Hinweis.
        XCTAssertNil(item.confusedPair(forTyped: "프랑스"))
    }

    /// Wort→Bedeutung: Tippt man die Bedeutung eines anderen bekannten Worts, wird dessen
    /// Paar gefunden.
    func testConfusedPairWordToMeaning() throws {
        let (_, item) = try makeSession(direction: .wordToMeaning)
        XCTAssertEqual(item.confusedPair(forTyped: "Japan"),
                       WordPair(word: "일본", meaning: "Japan"))
        // Die gesuchte Bedeutung selbst ist keine Verwechslung.
        XCTAssertNil(item.confusedPair(forTyped: "Deutschland"))
    }

    /// Der Verwechslungs-Pool umfasst den *gesamten* Wortschatz, nicht nur den Übungs-Scope:
    /// Ein Wort, das weder in der Session noch im Distraktor-Pool steckt, aber im Store
    /// existiert, wird trotzdem als Verwechslung erkannt.
    func testConfusedPairSpansWholeVocabularyNotJustSession() throws {
        let germany = Vocab(word: "독일", meaning: "Deutschland")
        let japan = Vocab(word: "일본", meaning: "Japan")
        context.insert(germany)
        context.insert(japan) // im Store, aber NICHT in Session/Distraktor-Pool
        let session = PracticeSession(
            vocabs: [germany], distractorPool: [germany],
            config: PracticeConfig(direction: .meaningToWord, modes: [.writing]), context: context
        )
        let item = try XCTUnwrap(session.items.first { $0.vocab.id == germany.id })
        XCTAssertEqual(item.confusedPair(forTyped: "일본"),
                       WordPair(word: "일본", meaning: "Japan"))
    }

    /// Ein bedeutungsgleiches Wort (Synonym) ist keine Verwechslung – es wird bereits als
    /// „fast richtig" behandelt und darf hier keinen Hinweis erzeugen.
    func testConfusedPairIgnoresSynonyms() throws {
        let a = Vocab(word: "고맙습니다", meaning: "Danke")
        let b = Vocab(word: "감사합니다", meaning: "Danke")
        context.insert(a)
        context.insert(b)
        let all = [a, b]
        let session = PracticeSession(
            vocabs: all, distractorPool: all,
            config: PracticeConfig(direction: .meaningToWord, modes: [.writing]), context: context
        )
        let item = try XCTUnwrap(session.items.first { $0.vocab.id == a.id })
        XCTAssertNil(item.confusedPair(forTyped: "감사합니다"))
    }
}
