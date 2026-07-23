import SwiftData
import SwiftUI

/// Anlegen oder Bearbeiten einer Vokabel.
struct VocabEditView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let vocab: Vocab? // nil = neue Vokabel
    let group: VocabGroup? // Zielgruppe (für neue Vokabel erforderlich)

    @Query(sort: \VocabGroup.sortOrder) private var allGroups: [VocabGroup]

    @State private var word: String
    @State private var meaning: String
    @State private var example: String
    @State private var emoji: String
    @State private var status: LearningStatus
    @State private var includeInWidget: Bool
    @State private var selectedGroup: VocabGroup?
    /// Sobald der Nutzer das Emoji-Feld selbst anfasst (tippen, Vorschlag übernehmen,
    /// entfernen), überschreibt die automatische Vorschlagslogik es nicht mehr.
    @State private var emojiTouchedManually: Bool

    init(vocab: Vocab?, group: VocabGroup?) {
        self.vocab = vocab
        self.group = group ?? vocab?.group
        _word = State(initialValue: vocab?.word ?? "")
        _meaning = State(initialValue: vocab?.meaning ?? "")
        _example = State(initialValue: vocab?.example ?? "")
        _emoji = State(initialValue: vocab?.emoji ?? "")
        _status = State(initialValue: vocab?.status ?? .new)
        _includeInWidget = State(initialValue: vocab?.includeInWidget ?? false)
        _selectedGroup = State(initialValue: group ?? vocab?.group)
        // Bestehende Vokabeln mit Emoji gelten als „vom Nutzer gesetzt", damit ein
        // späterer Bedeutungswechsel das gepflegte Emoji nicht automatisch ersetzt.
        _emojiTouchedManually = State(initialValue: (vocab?.emoji?.isEmpty == false))
    }

    /// Aktueller Vorschlag anhand der Bedeutung (oder `nil`, wenn nichts passt).
    private var emojiSuggestion: String? {
        EmojiSuggestionService.suggest(for: meaning)
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
                        .lineLimit(2 ... 5)
                }

                emojiSection

                if !allGroups.isEmpty {
                    Section(L("vocab.group")) {
                        Picker(L("vocab.group"), selection: $selectedGroup) {
                            ForEach(allGroups) { g in
                                Text(g.name).tag(Optional(g))
                            }
                        }
                        .pickerStyle(.menu)
                    }
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
            // Solange der Nutzer das Emoji nicht selbst angefasst hat, folgt es
            // automatisch dem Vorschlag zur (sich ändernden) Bedeutung.
            .onChange(of: meaning) {
                guard !emojiTouchedManually else { return }
                emoji = emojiSuggestion ?? ""
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background.ignoresSafeArea())
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

    /// Abschnitt für die optionale Emoji-Merkhilfe: großes Vorschau-Emoji, ein Feld für
    /// manuelle Eingabe (Standard-Emoji-Tastatur), Entfernen-Button und – falls vorhanden –
    /// ein Button, um den automatischen Vorschlag zu übernehmen.
    @ViewBuilder private var emojiSection: some View {
        Section {
            HStack(spacing: 12) {
                Text(emoji.isEmpty ? "–" : emoji)
                    .font(.largeTitle)
                    .frame(minWidth: 44)
                    .foregroundStyle(emoji.isEmpty ? Color.secondary : Color.primary)
                    .accessibilityHidden(true)

                TextField(L("vocab.emojiPlaceholder"), text: emojiBinding)

                if !emoji.isEmpty {
                    Button {
                        emoji = ""
                        emojiTouchedManually = true
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(L("vocab.emojiRemove"))
                }
            }

            if let suggestion = emojiSuggestion, suggestion != emoji {
                Button {
                    emoji = suggestion
                    emojiTouchedManually = true
                } label: {
                    Label(L("vocab.emojiSuggestion", suggestion), systemImage: "wand.and.stars")
                }
            }
        } header: {
            Text(L("vocab.emojiSection"))
        } footer: {
            Text(L("vocab.emojiHint"))
        }
    }

    /// Binding, das jede manuelle Eingabe auf genau ein Emoji begrenzt und das Feld als
    /// „vom Nutzer angefasst" markiert (siehe `emojiTouchedManually`).
    private var emojiBinding: Binding<String> {
        Binding(
            get: { emoji },
            set: { newValue in
                emojiTouchedManually = true
                // Auf das erste (Emoji-)Zeichen begrenzen – ein einzelnes Symbol als Merkhilfe.
                emoji = newValue.first.map(String.init) ?? ""
            }
        )
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
            target = Vocab(word: trimmedWord, meaning: trimmedMeaning, group: selectedGroup ?? group)
            context.insert(target)
        }
        target.example = trimmedExample.isEmpty ? nil : trimmedExample
        let trimmedEmoji = emoji.trimmingCharacters(in: .whitespacesAndNewlines)
        target.emoji = trimmedEmoji.isEmpty ? nil : trimmedEmoji
        target.includeInWidget = includeInWidget
        // Gruppe zuweisen/verschieben (auch aus der Suche heraus möglich).
        if let selectedGroup { target.group = selectedGroup }

        // Status nur überschreiben, wenn manuell geändert.
        if status != target.status {
            target.setStatusManually(status)
        }

        context.saveOrLog()
        WidgetSnapshotWriter.refresh(context: context)
        dismiss()
    }
}
