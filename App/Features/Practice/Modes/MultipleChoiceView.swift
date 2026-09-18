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
                if !isCorrect, let note = mnemonic {
                    HStack(alignment: .top, spacing: Theme.Spacing.s) {
                        Text("📝")
                        Text(note)
                            .font(.appBody)
                            .foregroundStyle(Theme.inkSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .paperCard(padding: Theme.Spacing.m)
                }
                Button {
                    onAnswer(isCorrect)
                } label: {
                    Label(isCorrect ? L("common.next") : L("practice.understood"),
                          systemImage: "arrow.right")
                }
                .buttonStyle(isCorrect ? .forward : .acknowledge)
            }
        }
    }

    /// Merknotiz nach falscher Antwort: Beispielsatz, sonst die Bedeutung.
    private var mnemonic: String? {
        if let example = item.vocab.example, !example.isEmpty { return example }
        let meaning = item.vocab.meaning
        return meaning.isEmpty ? nil : meaning
    }
}
