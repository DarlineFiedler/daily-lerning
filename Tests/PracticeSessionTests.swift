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

    // MARK: - Live-Kombo (#90)

    /// Aufeinanderfolgende richtige Antworten erhöhen die Kombo; ein Fehler reißt sie ab.
    func testComboCountsUpAndResetsOnWrong() {
        let vocabs = makeVocabs(4)
        let session = PracticeSession(
            vocabs: vocabs, distractorPool: vocabs,
            config: PracticeConfig(modes: [.review]), context: context
        )
        XCTAssertEqual(session.currentCombo, 0)
        session.submit(correct: true)
        session.submit(correct: true)
        XCTAssertEqual(session.currentCombo, 2)
        session.submit(correct: false)
        XCTAssertEqual(session.currentCombo, 0) // Fehler → Kombo abgerissen
        session.submit(correct: true)
        XCTAssertEqual(session.currentCombo, 1)
    }

    /// `maxCombo` hält das je erreichte Kombo-Maximum, auch nachdem die laufende Kombo
    /// durch einen Fehler zurückgesetzt wurde.
    func testMaxComboTracksHighest() {
        let vocabs = makeVocabs(5)
        let session = PracticeSession(
            vocabs: vocabs, distractorPool: vocabs,
            config: PracticeConfig(modes: [.review]), context: context
        )
        session.submit(correct: true)
        session.submit(correct: true)
        session.submit(correct: true) // Kombo 3
        session.submit(correct: false) // Reset
        session.submit(correct: true) // Kombo 1
        XCTAssertEqual(session.currentCombo, 1)
        XCTAssertEqual(session.maxCombo, 3)
    }

    /// `restart()` beginnt die Runde frisch – Kombo und Maximum werden zurückgesetzt.
    func testRestartResetsCombo() {
        let vocabs = makeVocabs(2)
        let session = PracticeSession(
            vocabs: vocabs, distractorPool: vocabs,
            config: PracticeConfig(modes: [.review]), context: context
        )
        session.submit(correct: true)
        session.submit(correct: true)
        XCTAssertEqual(session.maxCombo, 2)
        session.restart()
        XCTAssertEqual(session.currentCombo, 0)
        XCTAssertEqual(session.maxCombo, 0)
    }

    /// Die Meilenstein-Schwelle greift bei jeder fünften Kombo (5, 10, 15 …).
    func testComboMilestoneDetection() {
        XCTAssertFalse(PracticeSession.isComboMilestone(0))
        XCTAssertFalse(PracticeSession.isComboMilestone(4))
        XCTAssertTrue(PracticeSession.isComboMilestone(5))
        XCTAssertFalse(PracticeSession.isComboMilestone(6))
        XCTAssertTrue(PracticeSession.isComboMilestone(10))
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

    /// Große Runde mit großem Distraktor-Pool: jede Karte muss weiterhin 4 Optionen
    /// mit eindeutiger Antwortseite (inkl. Zielwort) liefern. Sichert das Verhalten
    /// nach der Umstellung auf vorberechnete, faul ausgewertete Distraktor-Tiers.
    func testChoicesRemainValidForLargeSession() {
        let group = makeGroup("G")
        let vocabs = makeVocabs(200, group: group)
        let extra = makeVocabs(300, group: makeGroup("H"), prefix: "x")
        let practice = PracticeSession(
            vocabs: vocabs, distractorPool: vocabs + extra,
            config: PracticeConfig(modes: [.multipleChoice]), context: context
        )
        XCTAssertEqual(practice.items.count, 200)
        for item in practice.items {
            XCTAssertEqual(item.choices.count, 4)
            XCTAssertEqual(Set(item.choices.map(\.meaning)).count, 4) // eindeutige Antwortseite
            XCTAssertTrue(item.choices.contains { $0.id == item.vocab.id }) // Zielwort dabei
        }
    }

    // MARK: - „Fast richtig" / bedeutungsgleiche Wörter

    /// Zwei Karten mit gleicher Bedeutung: in Richtung Bedeutung→Wort trägt jedes Item
    /// das jeweils andere Wort als Synonym, damit eine inhaltlich richtige, aber andere
    /// Übersetzung als „fast richtig" erkannt werden kann.
    func testSynonymWordsPopulatedForMeaningToWord() throws {
        let a = Vocab(word: "고맙습니다", meaning: "Danke")
        let b = Vocab(word: "감사합니다", meaning: "Danke")
        context.insert(a)
        context.insert(b)
        let all = [a, b]
        let session = PracticeSession(
            vocabs: all, distractorPool: all,
            config: PracticeConfig(direction: .meaningToWord, modes: [.writing]), context: context
        )
        let itemA = try XCTUnwrap(session.items.first { $0.vocab.id == a.id })
        XCTAssertEqual(itemA.synonymWords, ["감사합니다"])
    }

    /// In Richtung Wort→Bedeutung ist das Wort selbst der Prompt – Synonyme spielen keine
    /// Rolle, die Liste bleibt leer.
    func testSynonymWordsEmptyForWordToMeaning() {
        let a = Vocab(word: "고맙습니다", meaning: "Danke")
        let b = Vocab(word: "감사합니다", meaning: "Danke")
        context.insert(a)
        context.insert(b)
        let all = [a, b]
        let session = PracticeSession(
            vocabs: all, distractorPool: all,
            config: PracticeConfig(direction: .wordToMeaning, modes: [.writing]), context: context
        )
        XCTAssertTrue(session.items.allSatisfy { $0.synonymWords.isEmpty })
    }

    /// Auswahl-Modus: Ist eine bedeutungsgleiche Karte das Zielwort, darf die andere Karte
    /// (gleiche Bedeutung ⇒ ebenfalls richtige Antwort) nicht als Distraktor auftauchen –
    /// sonst wäre die Frage doppeldeutig. (Als bloße Distraktoren zu einem *dritten* Zielwort
    /// dürfen beide dagegen erscheinen; dann ist nur das Ziel korrekt.)
    func testChoicesExcludeSameMeaningDistractorWhenTargeted() {
        let a = Vocab(word: "고맙습니다", meaning: "Danke")
        let b = Vocab(word: "감사합니다", meaning: "Danke")
        context.insert(a)
        context.insert(b)
        let fillers = makeVocabs(10, prefix: "x")
        let all = [a, b] + fillers
        let session = PracticeSession(
            vocabs: all, distractorPool: all,
            config: PracticeConfig(direction: .meaningToWord, modes: [.multipleChoice]),
            context: context
        )
        for item in session.items {
            let ids = Set(item.choices.map(\.id))
            if item.vocab.id == a.id { XCTAssertFalse(ids.contains(b.id)) }
            if item.vocab.id == b.id { XCTAssertFalse(ids.contains(a.id)) }
        }
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

    /// Im reinen Lückentext-Modus fallen Wörter weg, deren Beispielsatz das Wort nicht
    /// wörtlich enthält (die Lücke würde sonst die Antwort zeigen statt sie zu verbergen).
    func testClozeOnlySkipsWordsWhoseExampleLacksTheWord() {
        let matching = Vocab(word: "가다", meaning: "gehen", example: "학교에 가다")
        let inflectedOnly = Vocab(word: "가다", meaning: "gehen", example: "학교에 갔어요")
        context.insert(matching)
        context.insert(inflectedOnly)
        let all = [matching, inflectedOnly]
        let session = PracticeSession(
            vocabs: all, distractorPool: all,
            config: PracticeConfig(modes: [.cloze]), context: context
        )
        XCTAssertEqual(session.total, 1)
        XCTAssertEqual(session.items.first?.vocab.id, matching.id)
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

    // MARK: - record(result:for:)

    /// `record(result:for:)` verbucht ein bestimmtes Wort und rückt den Fortschritt vor.
    func testRecordResultBooksSpecificVocabAndAdvances() throws {
        let vocabs = makeVocabs(3)
        let session = PracticeSession(
            vocabs: vocabs, distractorPool: vocabs,
            config: PracticeConfig(modes: [.review]), context: context
        )
        let target = try XCTUnwrap(session.items.last).vocab
        session.record(result: false, for: target)
        XCTAssertEqual(session.index, 1)
        XCTAssertEqual(session.wrongCount, 1)
        XCTAssertEqual(session.missedVocabs.first?.id, target.id)
        XCTAssertGreaterThanOrEqual(target.totalWrongCount, 1)
    }
}
