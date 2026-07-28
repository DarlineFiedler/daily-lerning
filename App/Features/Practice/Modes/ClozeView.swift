import SwiftUI

/// Modus 5: Lückentext. Der gespeicherte Beispielsatz wird mit dem gesuchten Wort als
/// Lücke gezeigt; das fehlende Wort wird eingetippt und (tolerant, wie beim Schreiben)
/// mit `Vocab.word` verglichen. Nur Wörter mit Beispielsatz landen in diesem Modus.
struct ClozeView: View {
    let item: PracticeItem
    let onAnswer: (Bool) -> Void

    @State private var typed = ""
    @State private var checked = false
    @State private var wasCorrect = false
    @FocusState private var focused: Bool

    /// Das gesuchte Wort ist immer die Lernsprache (Hangul).
    private var answer: String { item.vocab.word }

    private var sentence: String {
        ClozeText.blanked(example: ClozeText.usableExample(for: item.vocab) ?? "", word: answer)
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.l) {
            clozeCard

            TextField(L("practice.cloze.typeWord"), text: $typed)
                .font(.appTitle3)
                .padding(Theme.Spacing.m)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous)
                        .strokeBorder(Theme.brandStart.opacity(0.3), lineWidth: 1.5)
                )
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .focused($focused)
                .disabled(checked)
                .onSubmit { if !checked { check() } }

            if checked {
                resultBanner
                actionButtons
            } else {
                Button(action: check) {
                    Label(L("practice.check"), systemImage: "checkmark")
                }
                .buttonStyle(.primary)
                .disabled(typed.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .onAppear { focused = true }
    }

    private var clozeCard: some View {
        VStack(spacing: Theme.Spacing.s) {
            Text(sentence)
                .font(.appTitle2)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.5)
            Text(L("practice.cloze.meaningHint", item.vocab.meaning))
                .font(.appHeadline)
                .opacity(0.9)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.xl + 8)
        .padding(.horizontal, Theme.Spacing.m)
        .background(Theme.brandGradientSoft, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .foregroundStyle(.white)
        .shadow(color: Theme.brandStart.opacity(0.3), radius: 16, y: 8)
    }

    private var resultBanner: some View {
        VStack(spacing: 6) {
            Label(
                wasCorrect ? L("practice.correct") : L("practice.wrong"),
                systemImage: wasCorrect ? "checkmark.circle.fill" : "xmark.circle.fill"
            )
            .font(.appHeadline)
            .foregroundStyle(wasCorrect ? LearningStatus.learned.color : Theme.wrong)

            if !wasCorrect {
                HStack(spacing: Theme.Spacing.s) {
                    Text(answer)
                        .font(.appTitle3)
                    SpeakButton(text: answer)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(Theme.Spacing.m)
        .background((wasCorrect ? LearningStatus.learned.color : Theme.wrong).opacity(0.14),
                    in: RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous))
    }

    @ViewBuilder
    private var actionButtons: some View {
        if wasCorrect {
            Button { onAnswer(true) } label: {
                Label(L("common.next"), systemImage: "arrow.right")
            }
            .buttonStyle(.primary)
        } else {
            VStack(spacing: Theme.Spacing.s) {
                Button { onAnswer(true) } label: {
                    Label(L("practice.markCorrect"), systemImage: "hand.thumbsup")
                }
                .buttonStyle(.secondary(tint: LearningStatus.learned.color))

                Button { onAnswer(false) } label: {
                    Label(L("common.next"), systemImage: "arrow.right")
                }
                .buttonStyle(.primary)
            }
        }
    }

    private func check() {
        wasCorrect = AnswerChecker.isCorrect(typed: typed, expected: answer)
        withAnimation { checked = true }
        focused = false
    }
}
