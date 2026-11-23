import SwiftUI

/// Modus 5: Lückentext. Der gespeicherte Beispielsatz wird mit dem gesuchten Wort als
/// Lücke gezeigt; das fehlende Wort wird eingetippt und (tolerant, wie beim Schreiben)
/// mit `Vocab.word` verglichen. Nur Wörter mit Beispielsatz landen in diesem Modus.
/// Eingabe, Prüfen/Aufgeben und Aktions-Buttons liefert `TypedAnswerScaffold`.
struct ClozeView: View {
    let item: PracticeItem
    let onAnswer: (Bool) -> Void

    @State private var wasCorrect = false

    /// Das gesuchte Wort ist immer die Lernsprache (Hangul).
    private var answer: String { item.vocab.word }

    private var sentence: String {
        ClozeText.blanked(example: ClozeText.usableExample(for: item.vocab) ?? "", word: answer)
    }

    private var bannerTint: Color {
        wasCorrect ? LearningStatus.learned.color : Theme.wrong
    }

    var body: some View {
        TypedAnswerScaffold(
            placeholder: L("practice.cloze.typeWord"),
            underline: Theme.vermillion,
            bannerTint: bannerTint,
            evaluate: { typed in
                wasCorrect = AnswerChecker.isCorrect(typed: typed, expected: answer)
                return wasCorrect
            },
            onGiveUp: { wasCorrect = false },
            onAnswer: onAnswer,
            prompt: { clozeCard },
            bannerContent: { bannerContent }
        )
    }

    private var clozeCard: some View {
        VStack(spacing: Theme.Spacing.s) {
            Text(sentence)
                .font(.appDisplay(28, weight: .regular))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.5)
                // Lückensatz ist Koreanisch – für die VoiceOver-Aussprache auszeichnen.
                .accessibilityLabel(Text.speech(sentence, korean: true))
            Text(L("practice.cloze.meaningHint", item.vocab.meaning))
                .font(.appHand(19))
                .foregroundStyle(Theme.inkSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.xl + 8)
        .padding(.horizontal, Theme.Spacing.m)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .strokeBorder(Theme.hairline, lineWidth: 1)
        )
        .hardShadow(x: 3, y: 4)
    }

    @ViewBuilder
    private var bannerContent: some View {
        Label(
            wasCorrect ? L("practice.correct") : L("practice.wrong"),
            systemImage: wasCorrect ? "checkmark.circle.fill" : "xmark.circle.fill"
        )
        .font(.appHeadline)
        .foregroundStyle(bannerTint)

        if !wasCorrect {
            HStack(spacing: Theme.Spacing.s) {
                Text(answer)
                    .font(.appTitle3)
                SpeakButton(text: answer)
            }
        }
    }
}
