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
            let choices = Self.makeChoices(for: vocab, pool: distractorPool)
            return PracticeItem(vocab: vocab, mode: mode, direction: direction, choices: choices)
        }
    }

    var isFinished: Bool { index >= items.count }
    var currentItem: PracticeItem? { isFinished ? nil : items[index] }
    var total: Int { items.count }
    var position: Int { min(index + 1, total) }

    /// Verbucht das Ergebnis für das aktuelle Wort und geht zum nächsten.
    func submit(correct: Bool) {
        guard let item = currentItem else { return }
        item.vocab.registerResult(correct: correct)
        if correct { correctCount += 1 } else { wrongCount += 1 }
        try? context.save()
        WidgetSnapshotWriter.refresh(context: context)
        index += 1
    }

    /// Startet denselben Satz Wörter erneut.
    func restart() {
        index = 0
        correctCount = 0
        wrongCount = 0
    }

    // MARK: - Multiple-Choice-Optionen

    private static func makeChoices(for vocab: Vocab, pool: [Vocab]) -> [Vocab] {
        let others = pool.filter { $0.id != vocab.id }
        // Distraktoren mit möglichst eindeutiger Antwortseite auswählen.
        let distractors = Array(others.shuffled().prefix(3))
        return ([vocab] + distractors).shuffled()
    }
}

/// Vergleicht Schreib-Antworten (normalisiert, mehrere Varianten via „/“ oder „,“).
enum AnswerChecker {
    static func isCorrect(typed: String, expected: String) -> Bool {
        let normalizedTyped = normalize(typed)
        guard !normalizedTyped.isEmpty else { return false }
        let variants = expected
            .split(whereSeparator: { $0 == "/" || $0 == "," || $0 == ";" })
            .map { normalize(String($0)) }
        return variants.contains(normalizedTyped)
    }

    private static func normalize(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: nil)
    }
}
