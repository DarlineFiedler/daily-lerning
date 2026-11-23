@testable import DailyHangul
import SwiftData
import XCTest

/// Prüft den store-gestützten Teil von `AchievementService.metrics`: dass total,
/// learned und die Pro-Gruppe-Meisterschaft korrekt aus dem **einen** Vocab-Fetch
/// abgeleitet werden (Issue #139). Besonders die Grenzfälle, die der frühere
/// VocabGroup-Fetch implizit abdeckte: Wörter ohne Gruppe und leere Gruppen.
@MainActor
final class AchievementMetricsTests: XCTestCase {

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

    /// Fügt `count` Wörter in `group` ein, davon die ersten `learned` als gelernt.
    private func insert(count: Int, learned: Int, into group: VocabGroup?) {
        for index in 0 ..< count {
            let vocab = Vocab(word: "w\(UUID().uuidString)", meaning: "m", group: group)
            if index < learned { vocab.status = .learned }
            context.insert(vocab)
        }
    }

    /// Gemischtes Szenario: eine große, komplett gelernte Gruppe (→ „any"), eine
    /// teils gelernte Gruppe, eine leere Gruppe und zwei gruppenlose Wörter. total und
    /// learned zählen alles; die Mastery-Ableitungen ignorieren leere/gruppenlose Wörter.
    func testMetricsDerivesCountsAndMasteryFromSingleFetch() throws {
        let min = AchievementService.themenMeisterMinSize
        let full = VocabGroup(name: "Voll")
        let partial = VocabGroup(name: "Teilweise")
        let empty = VocabGroup(name: "Leer")
        [full, partial, empty].forEach(context.insert)
        insert(count: min, learned: min, into: full) // komplett gelernt, >= MinSize
        insert(count: 3, learned: 1, into: partial) // teils gelernt
        insert(count: 2, learned: 1, into: nil) // gruppenlos: zählt in total/learned, in keine Gruppe
        try context.save()

        let metrics = AchievementService.metrics(context: context, progress: AchievementProgress())

        XCTAssertEqual(metrics.totalWords, min + 3 + 2)
        XCTAssertEqual(metrics.learnedWords, min + 1 + 1)
        XCTAssertTrue(metrics.groupMastered) // die volle Gruppe
        XCTAssertFalse(metrics.allGroupsMastered) // die teilweise Gruppe kippt „all"
        XCTAssertFalse(metrics.bigGardenBloomed) // keine Gruppe >= gardenBloomMinSize
    }

    /// Alle echten Gruppen komplett gelernt, dazu eine leere Gruppe und ungelernte
    /// gruppenlose Wörter: „all" muss trotzdem true sein. Fällt um, wenn leere Gruppen
    /// als ungemeistert zählen oder gruppenlose Wörter wie eine Gruppe behandelt werden.
    func testMetricsAllMasteredIgnoresEmptyGroupsAndGrouplessWords() throws {
        let min = AchievementService.themenMeisterMinSize
        let first = VocabGroup(name: "Eins")
        let second = VocabGroup(name: "Zwei")
        let empty = VocabGroup(name: "Leer")
        [first, second, empty].forEach(context.insert)
        insert(count: min, learned: min, into: first)
        insert(count: 2, learned: 2, into: second)
        insert(count: 3, learned: 0, into: nil) // gruppenlos, ungelernt
        try context.save()

        let metrics = AchievementService.metrics(context: context, progress: AchievementProgress())

        XCTAssertEqual(metrics.totalWords, min + 2 + 3)
        XCTAssertEqual(metrics.learnedWords, min + 2)
        XCTAssertTrue(metrics.groupMastered)
        XCTAssertTrue(metrics.allGroupsMastered)
        XCTAssertFalse(metrics.bigGardenBloomed)
    }

    /// Zwei Gruppen mit derselben domänischen `id` (kein Unique-Constraint) bleiben
    /// getrennte Buckets: die komplett gelernte Gruppe zählt als gemeistert, obwohl die
    /// andere mit gleicher UUID ungelernt ist.
    func testMetricsKeepsGroupsWithDuplicateIDSeparate() throws {
        let min = AchievementService.themenMeisterMinSize
        let learnedGroup = VocabGroup(name: "Gelernt")
        let openGroup = VocabGroup(name: "Offen")
        openGroup.id = learnedGroup.id
        [learnedGroup, openGroup].forEach(context.insert)
        insert(count: min, learned: min, into: learnedGroup)
        insert(count: 3, learned: 0, into: openGroup)
        try context.save()

        let metrics = AchievementService.metrics(context: context, progress: AchievementProgress())

        XCTAssertTrue(metrics.groupMastered)
        XCTAssertFalse(metrics.allGroupsMastered)
    }

    /// Eine einzelne, komplett gelernte Gruppe ab `gardenBloomMinSize` löst alle drei
    /// Mastery-Flags aus – prüft, dass die Pro-Gruppe-Zählung aus dem Vocab-Durchlauf
    /// stimmt (learned == count je Gruppe).
    func testMetricsBigGardenFromFullyLearnedLargeGroup() throws {
        let big = AchievementService.gardenBloomMinSize
        let group = VocabGroup(name: "Garten")
        context.insert(group)
        insert(count: big, learned: big, into: group)
        try context.save()

        let metrics = AchievementService.metrics(context: context, progress: AchievementProgress())

        XCTAssertEqual(metrics.totalWords, big)
        XCTAssertEqual(metrics.learnedWords, big)
        XCTAssertTrue(metrics.groupMastered)
        XCTAssertTrue(metrics.allGroupsMastered)
        XCTAssertTrue(metrics.bigGardenBloomed)
    }

    /// Ohne Wörter: keine Mastery, Zähler auf 0 (Guard gegen leeren Store).
    func testMetricsEmptyStore() {
        let metrics = AchievementService.metrics(context: context, progress: AchievementProgress())

        XCTAssertEqual(metrics.totalWords, 0)
        XCTAssertEqual(metrics.learnedWords, 0)
        XCTAssertFalse(metrics.groupMastered)
        XCTAssertFalse(metrics.allGroupsMastered)
        XCTAssertFalse(metrics.bigGardenBloomed)
    }
}
