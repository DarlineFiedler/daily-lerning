import SwiftUI

/// Modus 1: Multiple Choice mit 4 Antworten aus dem Gruppen-Pool.
struct MultipleChoiceView: View {
    let item: PracticeItem
    let onAnswer: (Bool) -> Void

    @State private var selected: Vocab?

    private var answered: Bool { selected != nil }
    private var isCorrect: Bool { selected?.id == item.vocab.id }

    var body: some View {
        VStack(spacing: Theme.Spacing.l) {
            PromptCard(text: item.prompt())

            VStack(spacing: Theme.Spacing.s + 4) {
                ForEach(item.choices) { choice in
                    Button {
                        if !answered { selected = choice }
                    } label: {
                        HStack {
                            Text(item.optionText(choice))
                                .font(.appBody.weight(.medium))
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.leading)
                            Spacer()
                            if answered, let icon = icon(for: choice) {
                                Image(systemName: icon.name)
                                    .foregroundStyle(icon.color)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(Theme.Spacing.m)
                        .background(background(for: choice), in: RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous)
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
                }
                .buttonStyle(.primary)
            }
        }
    }

    private func isRight(_ choice: Vocab) -> Bool { choice.id == item.vocab.id }

    private func icon(for choice: Vocab) -> (name: String, color: Color)? {
        if isRight(choice) { return ("checkmark.circle.fill", LearningStatus.learned.color) }
        if choice.id == selected?.id { return ("xmark.circle.fill", .red) }
        return nil
    }

    private func background(for choice: Vocab) -> Color {
        guard answered else { return Theme.surfaceMuted }
        if isRight(choice) { return LearningStatus.learned.color.opacity(0.18) }
        if choice.id == selected?.id { return Color.red.opacity(0.15) }
        return Theme.surfaceMuted
    }

    private func border(for choice: Vocab) -> Color {
        guard answered else { return .clear }
        if isRight(choice) { return LearningStatus.learned.color }
        if choice.id == selected?.id { return .red }
        return .clear
    }
}
