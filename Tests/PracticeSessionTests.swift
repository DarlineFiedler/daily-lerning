import XCTest
import SwiftData
@testable import DailyHangul

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

    private func makeVocabs(_ count: Int) -> [Vocab] {
        (0..<count).map { i in
            let v = Vocab(word: "단어\(i)", meaning: "Wort \(i)")
            context.insert(v)
            return v
        }
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
        for _ in 0..<3 { session.submit(correct: false) }
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
