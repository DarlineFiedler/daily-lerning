@testable import DailyHangul
import SwiftData
import XCTest

/// Prüft die Lern-Session-Engine: Wortanzahl-Begrenzung, Nachüben der falschen
/// Wörter und das Tracking von falschen/aufgestiegenen Wörtern.
@MainActor
final class PracticeSessionTests: XCTestCase {

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

    private func makeVocabs(_ count: Int, group: VocabGroup? = nil, prefix: String = "") -> [Vocab] {
        (0 ..< count).map { i in
            let v = Vocab(word: "\(prefix)단어\(i)", meaning: "\(prefix)Wort \(i)", group: group)
            context.insert(v)
            return v
        }
    }

    private func makeGroup(_ name: String) -> VocabGroup {
        let g = VocabGroup(name: name)
        context.insert(g)
        return g
    }

    func testWordLimitCapsItemCount() {
        let vocabs = makeVocabs(5)
        let session = PracticeSession(
            vocabs: vocabs, distractorPool: vocabs,
            config: PracticeConfig(modes: [.review], wordLimit: 3), context: context
        )
        XCTAssertEqual(session.total, 3)
    }

    func testNilWordLimitUsesWholePool() {
        let vocabs = makeVocabs(4)
        let session = PracticeSession(
            vocabs: vocabs, distractorPool: vocabs,
            config: PracticeConfig(modes: [.review], wordLimit: nil), context: context
        )
        XCTAssertEqual(session.total, 4)
    }

    func testTracksMissedAndLeveledUp() {
        let vocabs = makeVocabs(2)
        let session = PracticeSession(
            vocabs: vocabs, distractorPool: vocabs,
            config: PracticeConfig(modes: [.review]), context: context
        )
        // Erstes Wort richtig (neu → am Lernen ⇒ Aufstieg), zweites falsch.
        session.submit(correct: true)
        session.submit(correct: false)

        XCTAssertEqual(session.correctCount, 1)
        XCTAssertEqual(session.wrongCount, 1)
        XCTAssertEqual(session.missedVocabs.count, 1)
        XCTAssertEqual(session.leveledUpVocabs.count, 1)
        XCTAssertTrue(session.isFinished)
    }

    func testRetryWrongRebuildsFromMissedOnly() {
        let vocabs = makeVocabs(3)
        let session = PracticeSession(
            vocabs: vocabs, distractorPool: vocabs,
            config: PracticeConfig(modes: [.review]), context: context
        )
        // Alle drei falsch beantworten.
        for _ in 0 ..< 3 { session.submit(correct: false) }
        XCTAssertEqual(session.missedVocabs.count, 3)

        session.retryWrong()
        XCTAssertEqual(session.total, 3)
        XCTAssertEqual(session.index, 0)
        XCTAssertEqual(session.correctCount, 0)
        XCTAssertEqual(session.wrongCount, 0)
        XCTAssertTrue(session.missedVocabs.isEmpty)
    }

    func testRetryWrongIsNoOpWhenNothingMissed() {
        let vocabs = makeVocabs(2)
        let session = PracticeSession(
            vocabs: vocabs, distractorPool: vocabs,
            config: PracticeConfig(modes: [.review]), context: context
        )
        session.submit(correct: true)
        session.submit(correct: true)
        session.retryWrong()
        // Keine falschen Wörter ⇒ Items bleiben unverändert (voller Satz).
        XCTAssertEqual(session.total, 2)
    }

    func testAccuracyPercentage() {
        let vocabs = makeVocabs(4)
        let session = PracticeSession(
            vocabs: vocabs, distractorPool: vocabs,
            config: PracticeConfig(modes: [.review]), context: context
        )
        session.submit(correct: true)
        session.submit(correct: true)
        session.submit(correct: true)
        session.submit(correct: false)
        XCTAssertEqual(session.accuracy, 75)
    }

    func testAccuracyIsZeroBeforeAnyAnswer() {
        let vocabs = makeVocabs(3)
        let session = PracticeSession(
            vocabs: vocabs, distractorPool: vocabs,
            config: PracticeConfig(modes: [.review]), context: context
        )
        XCTAssertEqual(session.accuracy, 0)
    }

    /// Der Hör-Modus muss immer Wort→Bedeutung sein – auch wenn die Config eine
    /// andere Richtung vorgibt (siehe `PracticeSession.buildItems`).
    func testListeningModeForcesWordToMeaningDirection() {
        let vocabs = makeVocabs(5)
        let session = PracticeSession(
            vocabs: vocabs, distractorPool: vocabs,
            config: PracticeConfig(direction: .meaningToWord, modes: [.listening]),
            context: context
        )
        XCTAssertFalse(session.items.isEmpty)
        XCTAssertTrue(session.items.allSatisfy { $0.mode == .listening })
        XCTAssertTrue(session.items.allSatisfy { $0.direction == .wordToMeaning })
    }

    /// Distraktoren werden bevorzugt aus den Wörtern des laufenden Durchgangs
    /// gezogen: 4 Session-Wörter reichen exakt für Ziel + 3 Distraktoren, obwohl
    /// der Pool viel größer ist – jede Option muss ein Session-Wort sein.
    func testChoicesPreferSessionWords() {
        let session = makeVocabs(4)
        let extra = makeVocabs(16, prefix: "x")
        let sessionIDs = Set(session.map(\.id))
        let practice = PracticeSession(
            vocabs: session, distractorPool: session + extra,
            config: PracticeConfig(modes: [.multipleChoice]), context: context
        )
        XCTAssertFalse(practice.items.isEmpty)
        for item in practice.items {
            XCTAssertEqual(item.choices.count, 4)
            XCTAssertTrue(item.choices.allSatisfy { sessionIDs.contains($0.id) })
        }
    }

    /// Reicht die Session nicht, kommen die Distraktoren aus derselben Gruppe –
    /// nicht aus einer fremden Gruppe.
    func testChoicesFallBackToSameGroup() throws {
        let groupA = makeGroup("A")
        let groupB = makeGroup("B")
        let session = makeVocabs(1, group: groupA, prefix: "a")
        let moreA = makeVocabs(5, group: groupA, prefix: "a")
        let moreB = makeVocabs(5, group: groupB, prefix: "b")
        let groupAIDs = Set((session + moreA).map(\.id))
        let target = session[0]
        let practice = PracticeSession(
            vocabs: session, distractorPool: session + moreA + moreB,
            config: PracticeConfig(modes: [.multipleChoice]), context: context
        )
        let item = try XCTUnwrap(practice.items.first)
        let distractors = item.choices.filter { $0.id != target.id }
        XCTAssertEqual(distractors.count, 3)
        XCTAssertTrue(distractors.allSatisfy { groupAIDs.contains($0.id) })
    }

    /// Mini-Session (1 Wort ohne Gruppe): es müssen trotzdem 4 Optionen mit
    /// eindeutiger Antwortseite entstehen, aufgefüllt aus dem Rest des Pools.
    func testChoicesFillUpForTinySession() throws {
        let session = makeVocabs(1)
        let extra = makeVocabs(10, prefix: "x")
        let practice = PracticeSession(
            vocabs: session, distractorPool: session + extra,
            config: PracticeConfig(modes: [.multipleChoice]), context: context
        )
        let item = try XCTUnwrap(practice.items.first)
        XCTAssertEqual(item.choices.count, 4)
        let answers = item.choices.map(\.meaning)
        XCTAssertEqual(Set(answers).count, 4) // eindeutige Antwortseite, keine Duplikate
    }

    func testResolvedModesUsesExplicitModesWhenSet() {
        let config = PracticeConfig(modes: [.review, .writing])
        XCTAssertEqual(Set(config.resolvedModes), [.review, .writing])
    }

    func testAvailableModesFilterListeningByVoice() {
        XCTAssertFalse(PracticeMode.available(hasVoice: false).contains(.listening))
        XCTAssertTrue(PracticeMode.available(hasVoice: true).contains(.listening))
        // Nicht-Hör-Modi sind unabhängig von der Stimme immer dabei.
        XCTAssertTrue(PracticeMode.available(hasVoice: false).contains(.review))
    }
}
