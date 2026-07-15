import SwiftUI

/// Modus 1: Multiple Choice mit 4 Antworten aus dem Gruppen-Pool.
struct MultipleChoiceView: View {
    let item: PracticeItem
    let onAnswer: (Bool) -> Void

    @State private var selected: Vocab?

    private var answered: Bool { selected != nil }
    private var isCorrect: Bool { selected?.id == item.vocab.id }

    var body: some View {
        VStack(spacing: 24) {
            PromptCard(text: item.prompt())

            VStack(spacing: 12) {
                ForEach(item.choices) { choice in
                    Button {
                        if !answered { selected = choice }
                    } label: {
                        Text(item.optionText(choice))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(background(for: choice), in: RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(border(for: choice), lineWidth: 2)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(answered)
                }
            }

            if answered {
                Button {
                    onAnswer(isCorrect)
                } label: {
                    Label(L("common.next"), systemImage: "arrow.right")
                        .frame(maxWidth: .infinity).padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private func isRight(_ choice: Vocab) -> Bool { choice.id == item.vocab.id }

    private func background(for choice: Vocab) -> Color {
        guard answered else { return Color.gray.opacity(0.12) }
        if isRight(choice) { return Color.green.opacity(0.25) }
        if choice.id == selected?.id { return Color.red.opacity(0.25) }
        return Color.gray.opacity(0.12)
    }

    private func border(for choice: Vocab) -> Color {
        guard answered else { return .clear }
        if isRight(choice) { return .green }
        if choice.id == selected?.id { return .red }
        return .clear
    }
}
