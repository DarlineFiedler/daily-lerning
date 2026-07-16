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
    let items: [PracticeItem]
    private let context: ModelContext

    var index = 0
    var correctCount = 0
    var wrongCount = 0

    init(vocabs: [Vocab], distractorPool: [Vocab], config: PracticeConfig, context: ModelContext) {
        self.context = context
        let modes = config.resolvedModes

        self.items = vocabs.shuffled().map { vocab in
            let mode = modes.randomElement() ?? .review
            let direction = ResolvedDirection.resolve(config.direction)
            let choices = Self.makeChoices(for: vocab, pool: distractorPool, direction: direction)
            return PracticeItem(vocab: vocab, mode: mode, direction: direction, choices: choices)
        }
    }

    var isFinished: Bool { index >= items.count }
    var currentItem: PracticeItem? { isFinished ? nil : items[index] }
    var total: Int { items.count }
    var position: Int { min(index + 1, total) }

    /// Verbucht das Ergebnis für das aktuelle Wort und geht zum nächsten.
    /// Kein Widget-Refresh: Üben ändert nur Status/Counter, nie die im Widget
    /// gezeigten Wörter (word/meaning/includeInWidget). Der Snapshot wird beim
    /// App-Start, Wechsel in den Vordergrund und beim Bearbeiten aktualisiert.
    func submit(correct: Bool) {
        guard let item = currentItem else { return }
        item.vocab.registerResult(correct: correct)
        if correct { correctCount += 1 } else { wrongCount += 1 }
        context.saveOrLog()
        index += 1
    }

    /// Startet denselben Satz Wörter erneut.
    func restart() {
        index = 0
        correctCount = 0
        wrongCount = 0
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
