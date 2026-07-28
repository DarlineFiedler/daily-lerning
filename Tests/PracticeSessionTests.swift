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

    /// Falsche Antworten erhöhen `totalWrongCount` (Lebenszeit-Fehlerzähler); richtige
    /// Antworten lassen ihn unberührt – Grundlage für die Problemwort-Erkennung.
    func testWrongAnswersAccumulateTotalWrongCount() {
        let wrong = makeVocabs(3, prefix: "F")
        let correct = makeVocabs(2, prefix: "R")
        let wrongSession = PracticeSession(
            vocabs: wrong, distractorPool: wrong,
            config: PracticeConfig(modes: [.review]), context: context
        )
        for _ in 0 ..< 3 { wrongSession.submit(correct: false) }
        XCTAssertEqual(wrong.reduce(0) { $0 + $1.totalWrongCount }, 3)

        let correctSession = PracticeSession(
            vocabs: correct, distractorPool: correct,
            config: PracticeConfig(modes: [.review]), context: context
        )
        for _ in 0 ..< 2 { correctSession.submit(correct: true) }
        XCTAssertEqual(correct.reduce(0) { $0 + $1.totalWrongCount }, 0)
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
        let moreA = makeVocabs(5, group: groupA, prefix: "a2")
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

    // MARK: - Lückentext (#20)

    private func makeVocabsWithExample(_ count: Int, prefix: String = "") -> [Vocab] {
        (0 ..< count).map { i in
            let v = Vocab(word: "\(prefix)단어\(i)", meaning: "\(prefix)Wort \(i)",
                          example: "\(prefix)단어\(i) 예문")
            context.insert(v)
            return v
        }
    }

    /// Im reinen Lückentext-Modus werden Wörter ohne Beispielsatz übersprungen.
    func testClozeOnlySkipsWordsWithoutExample() {
        let withExample = makeVocabsWithExample(2, prefix: "e")
        let withoutExample = makeVocabs(3, prefix: "n")
        let all = withExample + withoutExample
        let session = PracticeSession(
            vocabs: all, distractorPool: all,
            config: PracticeConfig(modes: [.cloze]), context: context
        )
        XCTAssertEqual(session.total, 2)
        XCTAssertTrue(session.items.allSatisfy { $0.mode == .cloze })
    }

    /// Lückentext erzwingt Wort→Bedeutung (die Lücke ist immer das Wort).
    func testClozeForcesWordToMeaningDirection() {
        let vocabs = makeVocabsWithExample(3)
        let session = PracticeSession(
            vocabs: vocabs, distractorPool: vocabs,
            config: PracticeConfig(direction: .meaningToWord, modes: [.cloze]), context: context
        )
        XCTAssertFalse(session.items.isEmpty)
        XCTAssertTrue(session.items.allSatisfy { $0.direction == .wordToMeaning })
    }

    // MARK: - Memory (#53)

    func testIsMemorySessionOnlyWhenExclusive() {
        XCTAssertTrue(PracticeConfig(modes: [.memory]).isMemorySession)
        XCTAssertFalse(PracticeConfig(modes: [.memory, .review]).isMemorySession)
        XCTAssertFalse(PracticeConfig(modes: []).isMemorySession)
    }

    func testMemorySessionBuildsMemoryItems() {
        let vocabs = makeVocabs(6)
        let session = PracticeSession(
            vocabs: vocabs, distractorPool: vocabs,
            config: PracticeConfig(modes: [.memory]), context: context
        )
        XCTAssertTrue(session.isMemory)
        XCTAssertEqual(session.total, 6)
        XCTAssertTrue(session.items.allSatisfy { $0.mode == .memory })
    }

    /// Memory darf nie im Per-Karte-„Mix" (leere Auswahl = alle Modi) landen.
    func testMemoryNeverAppearsInMixPool() {
        let vocabs = makeVocabs(30)
        let session = PracticeSession(
            vocabs: vocabs, distractorPool: vocabs,
            config: PracticeConfig(modes: []), context: context
        )
        XCTAssertFalse(session.isMemory)
        XCTAssertFalse(session.items.contains { $0.mode == .memory })
    }

    /// `record(result:for:)` verbucht ein bestimmtes (out-of-order) Wort und rückt vor.
    func testRecordResultBooksSpecificVocabAndAdvances() throws {
        let vocabs = makeVocabs(3)
        let session = PracticeSession(
            vocabs: vocabs, distractorPool: vocabs,
            config: PracticeConfig(modes: [.memory]), context: context
        )
        let target = try XCTUnwrap(session.items.last).vocab
        session.record(result: false, for: target)
        XCTAssertEqual(session.index, 1)
        XCTAssertEqual(session.wrongCount, 1)
        XCTAssertEqual(session.missedVocabs.first?.id, target.id)
        XCTAssertGreaterThanOrEqual(target.totalWrongCount, 1)
    }

    /// Nach dem Buchen aller Paare ist die Memory-Session fertig (Runden-Auswertung läuft).
    func testMemorySessionFinishesAfterAllPairs() {
        let vocabs = makeVocabs(4)
        let session = PracticeSession(
            vocabs: vocabs, distractorPool: vocabs,
            config: PracticeConfig(modes: [.memory]), context: context
        )
        for vocab in vocabs { session.record(result: true, for: vocab) }
        XCTAssertTrue(session.isFinished)
        XCTAssertEqual(session.correctCount, 4)
    }

    /// Memory zählt nicht für das „alle Modi an einem Tag"-Badge (bliebe sonst unerreichbar).
    func testDailyBadgeModeCountExcludesMemory() {
        XCTAssertEqual(PracticeMode.dailyBadgeModeCount, PracticeMode.allCases.count - 1)
    }
}
