import SwiftUI

/// Modus 3: Schreiben. Antwort eingeben, mit hinterlegter Lösung vergleichen.
/// Bei falscher Eingabe „Trotzdem richtig“ (zählt als richtig) oder „Weiter“ (Counter 0).
struct WritingView: View {
    let item: PracticeItem
    let onAnswer: (Bool) -> Void

    @State private var typed = ""
    @State private var checked = false
    @State private var wasCorrect = false
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 24) {
            PromptCard(text: item.prompt())

            TextField(L("practice.typeAnswer"), text: $typed)
                .textFieldStyle(.roundedBorder)
                .font(.title3)
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
                        .frame(maxWidth: .infinity).padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
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
            .font(.headline)
            .foregroundStyle(wasCorrect ? .green : .red)

            if !wasCorrect {
                Text(item.answer())
                    .font(.title3.weight(.semibold))
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background((wasCorrect ? Color.green : Color.red).opacity(0.12),
                    in: RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private var actionButtons: some View {
        if wasCorrect {
            Button { onAnswer(true) } label: {
                Label(L("common.next"), systemImage: "arrow.right")
                    .frame(maxWidth: .infinity).padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
        } else {
            VStack(spacing: 12) {
                Button { onAnswer(true) } label: {
                    Label(L("practice.markCorrect"), systemImage: "hand.thumbsup")
                        .frame(maxWidth: .infinity).padding(.vertical, 6)
                }
                .buttonStyle(.bordered)
                .tint(.green)

                Button { onAnswer(false) } label: {
                    Label(L("common.next"), systemImage: "arrow.right")
                        .frame(maxWidth: .infinity).padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private func check() {
        wasCorrect = AnswerChecker.isCorrect(typed: typed, expected: item.answer())
        withAnimation { checked = true }
        focused = false
    }
}
