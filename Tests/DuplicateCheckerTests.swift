@testable import DailyHangul
import SwiftData
import XCTest

/// Prüft die Dubletten-Erkennung hinter dem Anlegen/Bearbeiten in `VocabEditView`
/// (siehe `DuplicateChecker.firstDuplicate`): Treffer in gleicher vs. anderer Gruppe,
/// kein Treffer, Case-/Diakritika-Insensitivität und der Ausschluss der bearbeiteten Vokabel.
@MainActor
final class DuplicateCheckerTests: XCTestCase {

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
    private func makeGroup(_ name: String) -> VocabGroup {
        let group = VocabGroup(name: name)
        context.insert(group)
        return group
    }

    @discardableResult
    private func makeVocab(_ word: String, in group: VocabGroup) -> Vocab {
        let vocab = Vocab(word: word, meaning: "x", group: group)
        context.insert(vocab)
        return vocab
    }

    private func allVocabs() throws -> [Vocab] {
        try context.fetch(FetchDescriptor<Vocab>())
    }

    // MARK: - Treffer in gleicher Gruppe

    func testDuplicateInSameGroup() throws {
        let group = makeGroup("Verben")
        let existing = makeVocab("가다", in: group)

        let match = DuplicateChecker.firstDuplicate(of: "가다", in: group, among: try allVocabs())
        XCTAssertEqual(match, .sameGroup(existing))
    }

    // MARK: - Treffer nur in anderer Gruppe

    func testDuplicateInOtherGroup() throws {
        let target = makeGroup("Essen")
        let other = makeGroup("Verben")
        let existing = makeVocab("가다", in: other)

        let match = DuplicateChecker.firstDuplicate(of: "가다", in: target, among: try allVocabs())
        XCTAssertEqual(match, .otherGroup(existing))
    }

    // MARK: - Kein Treffer

    func testNoDuplicate() throws {
        let group = makeGroup("Verben")
        makeVocab("가다", in: group)

        let match = DuplicateChecker.firstDuplicate(of: "오다", in: group, among: try allVocabs())
        XCTAssertNil(match)
    }

    func testEmptyWordIsNoDuplicate() throws {
        let group = makeGroup("Verben")
        makeVocab("가다", in: group)

        let match = DuplicateChecker.firstDuplicate(of: "   ", in: group, among: try allVocabs())
        XCTAssertNil(match)
    }

    // MARK: - Case-/Diakritika-Insensitivität + Trimmen

    func testCaseAndDiacriticInsensitive() throws {
        let group = makeGroup("Wörter")
        let existing = makeVocab("café", in: group)

        // Groß-/Kleinschreibung, fehlendes Diakritikum und umgebender Leerraum ignoriert.
        let match = DuplicateChecker.firstDuplicate(of: "  CAFE ", in: group, among: try allVocabs())
        XCTAssertEqual(match, .sameGroup(existing))
    }

    // MARK: - Ausschluss der bearbeiteten Vokabel

    func testExcludesEditedVocabItself() throws {
        let group = makeGroup("Verben")
        let editing = makeVocab("가다", in: group)

        // Beim Bearbeiten darf die Vokabel nicht sich selbst als Dublette melden.
        let match = DuplicateChecker.firstDuplicate(of: "가다", in: group,
                                                    among: try allVocabs(), excluding: editing)
        XCTAssertNil(match)
    }

    func testExcludingStillFindsRealDuplicate() throws {
        let group = makeGroup("Verben")
        let editing = makeVocab("가다", in: group)
        let twin = makeVocab("가다", in: group)

        // Selbst ausgeschlossen, aber eine echte zweite Dublette wird weiterhin gefunden.
        let match = DuplicateChecker.firstDuplicate(of: "가다", in: group,
                                                    among: try allVocabs(), excluding: editing)
        XCTAssertEqual(match, .sameGroup(twin))
    }

    // MARK: - Vorrang der gleichen Gruppe

    func testSameGroupTakesPrecedenceOverOtherGroup() throws {
        let target = makeGroup("Essen")
        let other = makeGroup("Verben")
        makeVocab("가다", in: other)
        let inTarget = makeVocab("가다", in: target)

        let match = DuplicateChecker.firstDuplicate(of: "가다", in: target, among: try allVocabs())
        XCTAssertEqual(match, .sameGroup(inTarget))
    }
}
