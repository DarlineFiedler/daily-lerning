import SwiftUI

/// Modus 3: Schreiben. Antwort eingeben, mit hinterlegter Lösung vergleichen.
/// Bei falscher Eingabe „Trotzdem richtig" (zählt als richtig) oder „Weiter" (Counter 0).
struct WritingView: View {
    let item: PracticeItem
    let onAnswer: (Bool) -> Void

    @State private var match: AnswerChecker.AnswerMatch = .wrong
    /// Bei falscher Eingabe: das (andere) Wort des Wortschatzes, das man stattdessen
    /// getippt hat – für den zusätzlichen „Verwechslungs"-Hinweis. `nil`, wenn die Eingabe
    /// keinem bekannten Wort entspricht.
    @State private var confused: WordPair?

    var body: some View {
        TypedAnswerScaffold(
            placeholder: L("practice.typeAnswer"),
            underline: Theme.ink,
            bannerTint: bannerColor,
            evaluate: evaluate,
            onGiveUp: {
                match = .wrong
                confused = nil
            },
            onAnswer: onAnswer,
            prompt: {
                PromptCard(text: item.prompt(),
                           spokenText: item.direction == .wordToMeaning ? item.vocab.word : nil,
                           isKoreanPrompt: item.direction == .wordToMeaning)
            },
            bannerContent: { bannerContent }
        )
    }

    /// Akzentfarbe des Ergebnis-Banners je nach Bewertung.
    private var bannerColor: Color {
        switch match {
        case .correct: LearningStatus.learned.color
        case .synonym: Theme.statusLearning
        case .wrong: Theme.wrong
        }
    }

    private var bannerTitle: String {
        switch match {
        case .correct: L("practice.correct")
        case .synonym: L("practice.almost")
        case .wrong: L("practice.wrong")
        }
    }

    private var bannerIcon: String {
        switch match {
        case .correct: "checkmark.circle.fill"
        case .synonym: "checkmark.circle.trianglebadge.exclamationmark"
        case .wrong: "xmark.circle.fill"
        }
    }

    @ViewBuilder
    private var bannerContent: some View {
        Label(bannerTitle, systemImage: bannerIcon)
            .font(.appHeadline)
            .foregroundStyle(bannerColor)

        // „Fast richtig": erklärt, dass die Bedeutung stimmt, aber ein anderes Wort
        // gefragt war. „Falsch": zeigt schlicht die gesuchte Antwort.
        if match == .synonym {
            Text(L("practice.almostHint", item.answer()))
                .font(.appSubheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.inkSecondary)
        }
        if match != .correct {
            HStack(spacing: Theme.Spacing.s) {
                Text(item.answer())
                    .font(.appTitle3)
                    .accessibilityLabel(Text.speech(item.answer(), korean: item.direction == .meaningToWord))
                if item.direction == .meaningToWord {
                    SpeakButton(text: item.vocab.word)
                }
            }
        }
        // Verwechslungs-Hinweis: die Eingabe gehört zu einem anderen bekannten Wort.
        if let confused {
            Text(L("practice.confusedHint", confused.word, confused.meaning))
                .font(.appSubheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.inkSecondary)
        }
    }

    /// Bewertet die Eingabe; nur ein exakter Treffer zählt als „voll richtig" (ein
    /// Synonym bietet wie eine falsche Eingabe „Trotzdem richtig" an).
    private func evaluate(_ typed: String) -> Bool {
        match = AnswerChecker.evaluate(typed: typed, expected: item.answer(),
                                       synonyms: item.synonymWords)
        // Bei falscher Eingabe prüfen, ob man ein anderes bekanntes Wort getippt hat – dann
        // dessen Bedeutung als Zusatzinfo einblenden. Läuft synchron; die Kandidaten-Varianten
        // sind vorberechnet (siehe `WordPair`), sodass der Abgleich günstig bleibt.
        confused = match == .wrong ? item.confusedPair(forTyped: typed) : nil
        return match == .correct
    }
}
