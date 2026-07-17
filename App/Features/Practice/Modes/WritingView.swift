import SwiftUI

/// Modus 3: Schreiben. Antwort eingeben, mit hinterlegter Lösung vergleichen.
/// Bei falscher Eingabe „Trotzdem richtig" (zählt als richtig) oder „Weiter" (Counter 0).
struct WritingView: View {
    let item: PracticeItem
    let onAnswer: (Bool) -> Void

    @State private var typed = ""
    @State private var checked = false
    @State private var wasCorrect = false
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: Theme.Spacing.l) {
            PromptCard(text: item.prompt(),
                       spokenText: item.direction == .wordToMeaning ? item.vocab.word : nil)

            TextField(L("practice.typeAnswer"), text: $typed)
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
                    Text(item.answer())
                        .font(.appTitle3)
                    if item.direction == .meaningToWord {
                        SpeakButton(text: item.vocab.word)
                    }
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
        wasCorrect = AnswerChecker.isCorrect(typed: typed, expected: item.answer())
        withAnimation { checked = true }
        focused = false
    }
}
