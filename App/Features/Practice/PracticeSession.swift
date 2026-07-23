import Foundation
import SwiftData

/// Eine vorbereitete Lernaufgabe (Wort + zugewiesener Modus/Richtung/Optionen).
struct PracticeItem: Identifiable {
    let id = UUID()
    let vocab: Vocab
    let mode: PracticeMode
    let direction: ResolvedDirection
    /// Für Multiple Choice: 4 gemischte Optionen (inkl. richtiger Antwort).
    let choices: [Vocab]

    func prompt() -> String {
        direction == .wordToMeaning ? vocab.word : vocab.meaning
    }

    func answer() -> String {
        direction == .wordToMeaning ? vocab.meaning : vocab.word
    }

    /// Die anzuzeigende Seite einer Antwortoption (die „Antwort-Seite“).
    func optionText(_ option: Vocab) -> String {
        direction == .wordToMeaning ? option.meaning : option.word
    }
}

/// Steuert einen Lernvorgang: Reihenfolge, Fortschritt, Ergebnisverbuchung.
@MainActor
@Observable
final class PracticeSession {
    private(set) var items: [PracticeItem]
    private let context: ModelContext
    private let distractorPool: [Vocab]
    private let config: PracticeConfig

    var index = 0
    var correctCount = 0
    var wrongCount = 0

    /// Falsch beantwortete Wörter (für Zusammenfassung + „Falsche wiederholen").
    private(set) var missedVocabs: [Vocab] = []
    /// Wörter, deren Status in dieser Session aufgestiegen ist.
    private(set) var leveledUpVocabs: [Vocab] = []
    /// In dieser Runde neu freigeschaltete Badges (für das Freischalt-Feedback).
    private(set) var newlyUnlocked: [Achievement] = []
    /// Wurde ein zuvor falsch beantwortetes Wort in dieser Runde richtig beantwortet?
    /// (für das „Selbstkorrektur"-Badge).
    private var didSelfCorrect = false
    /// Anzahl der in dieser Runde neu auf „gelernt" aufgestiegenen Wörter
    /// (für das „Ein Wort am Tag"-Badge).
    private var newlyLearnedCount = 0
    /// Verhindert, dass die Runden-Auswertung (Achievements) mehrfach läuft.
    private var didFinalize = false

    init(vocabs: [Vocab], distractorPool: [Vocab], config: PracticeConfig, context: ModelContext) {
        self.context = context
        self.distractorPool = distractorPool
        self.config = config
        // Wortanzahl begrenzen (nil = alle), danach Aufgaben bauen.
        let picked = config.wordLimit.map { Array(vocabs.shuffled().prefix($0)) } ?? vocabs.shuffled()
        self.items = Self.buildItems(from: picked, distractorPool: distractorPool, config: config)
    }

    var isFinished: Bool { index >= items.count }
    var currentItem: PracticeItem? { isFinished ? nil : items[index] }
    var total: Int { items.count }
    var position: Int { min(index + 1, total) }

    /// Trefferquote in Prozent (0, wenn noch nichts beantwortet).
    var accuracy: Int {
        let answered = correctCount + wrongCount
        return answered == 0 ? 0 : Int(round(Double(correctCount) / Double(answered) * 100))
    }

    /// Verbucht das Ergebnis für das aktuelle Wort und geht zum nächsten.
    /// Kein Widget-Refresh: Üben ändert nur Status/Counter, nie die im Widget
    /// gezeigten Wörter (word/meaning/includeInWidget). Der Snapshot wird beim
    /// App-Start, Wechsel in den Vordergrund und beim Bearbeiten aktualisiert.
    func submit(correct: Bool) {
        guard let item = currentItem else { return }
        let before = item.vocab.status
        // Zuvor falsch/zurückgesetzt? (geübt, aber Erfolgs-Counter auf 0) – für „Selbstkorrektur".
        let wasPreviouslyWrong = item.vocab.timesPracticed > 0 && item.vocab.successCounter == 0
        item.vocab.registerResult(correct: correct)
        if correct {
            correctCount += 1
            if wasPreviouslyWrong { didSelfCorrect = true }
            // Aufstieg? (rawValue steigt mit dem Lernfortschritt).
            if item.vocab.status.rawValue > before.rawValue {
                leveledUpVocabs.append(item.vocab)
                if item.vocab.status == .learned, before != .learned { newlyLearnedCount += 1 }
            }
        } else {
            wrongCount += 1
            missedVocabs.append(item.vocab)
        }
        StreakStore.registerActivity() // idempotent pro Kalendertag
        context.saveOrLog()
        index += 1
        if isFinished { finalizeRound() }
    }

    /// Einmalige Auswertung am Rundenende: Übungsrunde verbuchen und ggf. neue
    /// Badges freischalten. Idempotent pro Runde (`didFinalize`).
    private func finalizeRound() {
        guard !didFinalize else { return }
        didFinalize = true
        let now = Date.now
        // Fehlerfreie Runde mit genug Wörtern → „Makellos". `isFlawless` gilt für die
        // Fehlerfrei-Serie schon ohne Mindestwortzahl.
        let isPerfect = wrongCount == 0 && total >= 5
        let isFlawless = wrongCount == 0 && total >= 1
        newlyUnlocked = AchievementService.registerSession(
            modes: Set(items.map(\.mode)),
            date: now,
            isPerfect: isPerfect,
            isFlawless: isFlawless,
            selfCorrected: didSelfCorrect,
            newlyLearned: newlyLearnedCount,
            currentStreak: StreakStore.current,
            groups: Set(items.compactMap { $0.vocab.group?.id.uuidString }),
            context: context
        )
    }

    /// Startet denselben Satz Wörter erneut.
    func restart() {
        resetProgress()
    }

    /// Baut eine neue Runde nur aus den falsch beantworteten Wörtern.
    func retryWrong() {
        let wrong = missedVocabs
        guard !wrong.isEmpty else { return }
        items = Self.buildItems(from: wrong.shuffled(), distractorPool: distractorPool, config: config)
        resetProgress()
    }

    private func resetProgress() {
        index = 0
        correctCount = 0
        wrongCount = 0
        missedVocabs = []
        leveledUpVocabs = []
        newlyUnlocked = []
        didSelfCorrect = false
        newlyLearnedCount = 0
        didFinalize = false
    }

    // MARK: - Aufgaben-Aufbau

    /// Weist jedem Wort einen (zufälligen) Modus, eine aufgelöste Richtung und
    /// – für Auswahl-/Hör-Modi – vier Optionen zu.
    private static func buildItems(from vocabs: [Vocab], distractorPool: [Vocab], config: PracticeConfig) -> [PracticeItem] {
        let modes = config.resolvedModes
        return vocabs.map { vocab in
            let mode = modes.randomElement() ?? .review
            // Hör-Modus: immer Koreanisch hören → Bedeutung wählen.
            let direction = mode == .listening ? .wordToMeaning : ResolvedDirection.resolve(config.direction)
            let choices = makeChoices(for: vocab, pool: distractorPool, direction: direction)
            return PracticeItem(vocab: vocab, mode: mode, direction: direction, choices: choices)
        }
    }

    // MARK: - Multiple-Choice-Optionen

    private static func makeChoices(for vocab: Vocab, pool: [Vocab], direction: ResolvedDirection) -> [Vocab] {
        // Distraktoren mit eindeutiger Antwortseite auswählen: kein Distraktor
        // darf denselben Antworttext wie die richtige Antwort (oder ein bereits
        // gewählter Distraktor) haben – sonst wäre die Frage mehrdeutig.
        let answerText: (Vocab) -> String = {
            direction == .wordToMeaning ? $0.meaning : $0.word
        }
        var seenAnswers: Set<String> = [answerText(vocab)]
        var distractors: [Vocab] = []
        for candidate in pool.shuffled() where candidate.id != vocab.id {
            guard seenAnswers.insert(answerText(candidate)).inserted else { continue }
            distractors.append(candidate)
            if distractors.count == 3 { break }
        }
        return ([vocab] + distractors).shuffled()
    }
}

/// Vergleicht Schreib-Antworten (normalisiert, mehrere Varianten via „/“ „,“ „;“).
/// Sowohl die Eingabe als auch die erwartete Antwort werden in Varianten zerlegt,
/// damit z.B. die Eingabe „gehen, laufen“ gegen „gehen / laufen“ matcht.
enum AnswerChecker {
    static func isCorrect(typed: String, expected: String) -> Bool {
        let typedVariants = variants(of: typed)
        guard !typedVariants.isEmpty else { return false }
        return !typedVariants.isDisjoint(with: variants(of: expected))
    }

    /// Zerlegt einen String an „/“ „,“ „;“ in normalisierte, nicht-leere Varianten.
    private static func variants(of s: String) -> Set<String> {
        Set(
            s.split(whereSeparator: { $0 == "/" || $0 == "," || $0 == ";" })
                .map { normalize(String($0)) }
                .filter { !$0.isEmpty }
        )
    }

    private static func normalize(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: nil)
    }
}
