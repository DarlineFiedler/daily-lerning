@testable import DailyHangul
import SwiftData
import XCTest

/// Prüft die kombinierte Filter-Logik der globalen Suche (`SearchView.filter`):
/// Textmatch, Gruppen- und Statusfilter – einzeln und in Kombination, inkl.
/// Browsen ganz ohne Suchbegriff.
@MainActor
final class SearchFilterTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    private var verbs: VocabGroup!
    private var food: VocabGroup!

    override func setUp() {
        super.setUp()
        container = PersistenceController.makeContainer(inMemory: true)
        context = container.mainContext

        verbs = VocabGroup(name: "Verben")
        food = VocabGroup(name: "Essen")
        context.insert(verbs)
        context.insert(food)

        // Verben
        insert("가다", "gehen", group: verbs, status: .learned)
        insert("오다", "kommen", group: verbs, status: .new)
        // Essen
        insert("밥", "Reis", group: food, status: .learned)
        insert("김치", "Kimchi (Gericht)", group: food, status: .learning)
        try? context.save()
    }

    override func tearDown() {
        verbs = nil
        food = nil
        context = nil
        container = nil
        super.tearDown()
    }

    @discardableResult
    private func insert(_ word: String, _ meaning: String,
                        group: VocabGroup, status: LearningStatus) -> Vocab {
        let vocab = Vocab(word: word, meaning: meaning, group: group)
        if status != .new { vocab.setStatusManually(status) }
        context.insert(vocab)
        return vocab
    }

    private var all: [Vocab] {
        (try? context.fetch(FetchDescriptor<Vocab>())) ?? []
    }

    private func filter(query: String = "", groups: Set<UUID> = [],
                        statuses: Set<LearningStatus> = []) -> Set<String> {
        Set(SearchView.filter(all, query: query, groups: groups, statuses: statuses).map(\.word))
    }

    /// Ohne jegliches Kriterium bleibt die Suche leer (Startzustand).
    func testNoCriteriaReturnsEmpty() {
        XCTAssertTrue(filter().isEmpty)
    }

    func testTextMatchesWordAndMeaningCaseInsensitively() {
        XCTAssertEqual(filter(query: "gehen"), ["가다"])
        XCTAssertEqual(filter(query: "KIMCHI"), ["김치"])
        XCTAssertEqual(filter(query: "가"), ["가다"])
    }

    /// Reines Browsen nach Gruppe – ganz ohne Suchbegriff.
    func testGroupFilterOnly() {
        XCTAssertEqual(filter(groups: [verbs.id]), ["가다", "오다"])
    }

    /// Reines Browsen nach Status – ganz ohne Suchbegriff (Mehrfachauswahl).
    func testStatusFilterOnly() {
        XCTAssertEqual(filter(statuses: [.learned]), ["가다", "밥"])
        XCTAssertEqual(filter(statuses: [.learned, .learning]), ["가다", "밥", "김치"])
    }

    func testTextAndGroupCombined() {
        // "gehen" existiert nur in Verben; Filter auf Essen ⇒ leer.
        XCTAssertTrue(filter(query: "gehen", groups: [food.id]).isEmpty)
        XCTAssertEqual(filter(query: "gehen", groups: [verbs.id]), ["가다"])
    }

    func testGroupAndStatusCombined() {
        XCTAssertEqual(filter(groups: [food.id], statuses: [.learned]), ["밥"])
    }

    func testAllThreeCombined() {
        XCTAssertEqual(filter(query: "Reis", groups: [food.id], statuses: [.learned]), ["밥"])
        XCTAssertTrue(filter(query: "Reis", groups: [verbs.id], statuses: [.learned]).isEmpty)
    }
}
