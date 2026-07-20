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
            PromptCard(text: item.prompt(),
                       spokenText: item.direction == .wordToMeaning ? item.vocab.word : nil)

            ChoiceOptionsView(item: item, selected: $selected)

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
}
