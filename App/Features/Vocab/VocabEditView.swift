import SwiftUI
import SwiftData

/// Anlegen oder Bearbeiten einer Vokabel.
struct VocabEditView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let vocab: Vocab?          // nil = neue Vokabel
    let group: VocabGroup?     // Zielgruppe (für neue Vokabel erforderlich)

    @State private var word: String
    @State private var meaning: String
    @State private var example: String
    @State private var status: LearningStatus
    @State private var includeInWidget: Bool

    init(vocab: Vocab?, group: VocabGroup?) {
        self.vocab = vocab
        self.group = group ?? vocab?.group
        _word = State(initialValue: vocab?.word ?? "")
        _meaning = State(initialValue: vocab?.meaning ?? "")
        _example = State(initialValue: vocab?.example ?? "")
        _status = State(initialValue: vocab?.status ?? .new)
        _includeInWidget = State(initialValue: vocab?.includeInWidget ?? false)
    }

    private var canSave: Bool {
        !word.trimmingCharacters(in: .whitespaces).isEmpty &&
        !meaning.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(L("vocab.details")) {
                    TextField(L("vocab.wordPlaceholder"), text: $word)
                        .font(.title3)
                    TextField(L("vocab.meaningPlaceholder"), text: $meaning)
                    TextField(L("vocab.examplePlaceholder"), text: $example, axis: .vertical)
                        .lineLimit(2...5)
                }

                Section(L("vocab.status")) {
                    Picker(L("vocab.status"), selection: $status) {
                        ForEach(LearningStatus.allCases) { s in
                            Label(L(s.titleKey), systemImage: s.systemImage).tag(s)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section {
                    Toggle(isOn: $includeInWidget) {
                        Label(L("vocab.widgetToggle"), systemImage: "lock.iphone")
                    }
                }
            }
            .navigationTitle(vocab == nil ? L("vocab.new") : L("vocab.edit"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("common.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("common.save"), action: save).disabled(!canSave)
                }
            }
        }
    }

    private func save() {
        let trimmedWord = word.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedMeaning = meaning.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedExample = example.trimmingCharacters(in: .whitespacesAndNewlines)

        let target: Vocab
        if let vocab {
            target = vocab
            target.word = trimmedWord
            target.meaning = trimmedMeaning
        } else {
            target = Vocab(word: trimmedWord, meaning: trimmedMeaning, group: group)
            context.insert(target)
        }
        target.example = trimmedExample.isEmpty ? nil : trimmedExample
        target.includeInWidget = includeInWidget

        // Status nur überschreiben, wenn manuell geändert.
        if status != target.status {
            target.setStatusManually(status)
        }

        try? context.save()
        WidgetSnapshotWriter.refresh(context: context)
        dismiss()
    }
}
