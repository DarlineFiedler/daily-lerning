import SwiftData
import SwiftUI

/// Anlegen oder Bearbeiten einer Vokabel.
struct VocabEditView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let vocab: Vocab? // nil = neue Vokabel
    let group: VocabGroup? // Zielgruppe (für neue Vokabel erforderlich)
    /// Optionaler Callback, um statt einer Dublette zur bereits bestehenden Vokabel zu
    /// springen (siehe Duplikat-Dialog). Wenn `nil`, entfällt die „Zur bestehenden
    /// Vokabel"-Aktion.
    let onSelectExisting: ((Vocab) -> Void)?

    @Query(sort: \VocabGroup.sortOrder) private var allGroups: [VocabGroup]

    @State private var word: String
    @State private var meaning: String
    @State private var example: String
    @State private var emoji: String
    @State private var status: LearningStatus
    @State private var topikLevel: TopikLevel?
    @State private var includeInWidget: Bool
    @State private var selectedGroup: VocabGroup?
    /// Sobald der Nutzer das Emoji-Feld selbst anfasst (tippen, Vorschlag übernehmen,
    /// entfernen), überschreibt die automatische Vorschlagslogik es nicht mehr.
    @State private var emojiTouchedManually: Bool
    /// Bestehende Vokabel, deren Wort mit der Eingabe in derselben Gruppe kollidiert – löst
    /// beim Speichern den Warn-Dialog aus (statt still eine Dublette anzulegen).
    @State private var pendingDuplicate: Vocab?

    init(vocab: Vocab?, group: VocabGroup?, onSelectExisting: ((Vocab) -> Void)? = nil) {
        self.vocab = vocab
        self.group = group ?? vocab?.group
        self.onSelectExisting = onSelectExisting
        _word = State(initialValue: vocab?.word ?? "")
        _meaning = State(initialValue: vocab?.meaning ?? "")
        _example = State(initialValue: vocab?.example ?? "")
        _emoji = State(initialValue: vocab?.emoji ?? "")
        _status = State(initialValue: vocab?.status ?? .new)
        _topikLevel = State(initialValue: vocab?.topikLevel)
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

    /// Aktuelles Wort-Duplikat (falls vorhanden) gegen alle Vokabeln, die eigene Vokabel
    /// ausgenommen. Zielgruppe ist die aktuell gewählte Gruppe.
    private var duplicateMatch: DuplicateChecker.Match? {
        DuplicateChecker.firstDuplicate(of: word,
                                        in: selectedGroup ?? group,
                                        among: allGroups.flatMap(\.vocabs),
                                        excluding: vocab)
    }

    /// Dezenter Hinweis, wenn dasselbe Wort bereits in einer **anderen** Gruppe existiert –
    /// reine Info, kein Speicher-Stopp (gleiches Wort in mehreren Gruppen kann gewollt sein).
    private var otherGroupDuplicateHint: String? {
        guard case let .otherGroup(existing) = duplicateMatch else { return nil }
        let groupName = existing.group?.name ?? ""
        return L("vocab.duplicateOtherGroupHint", existing.word, groupName)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(L("vocab.wordPlaceholder"), text: $word)
                        .font(.title3)
                    TextField(L("vocab.meaningPlaceholder"), text: $meaning)
                    TextField(L("vocab.examplePlaceholder"), text: $example, axis: .vertical)
                        .lineLimit(2 ... 5)
                } header: {
                    Text(L("vocab.details"))
                } footer: {
                    if let otherGroupDuplicateHint {
                        Label(otherGroupDuplicateHint, systemImage: "info.circle")
                            .foregroundStyle(.secondary)
                    }
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

                Section(L("topik.level")) {
                    Picker(L("topik.level"), selection: $topikLevel) {
                        Text(L("topik.none")).tag(TopikLevel?.none)
                        ForEach(TopikLevel.allCases) { level in
                            Text(L(level.titleKey)).tag(TopikLevel?.some(level))
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
                    Button(L("common.save"), action: attemptSave).disabled(!canSave)
                }
            }
            .confirmationDialog(
                L("vocab.duplicateSameGroupTitle", word.trimmingCharacters(in: .whitespacesAndNewlines)),
                isPresented: Binding(
                    get: { pendingDuplicate != nil },
                    set: { if !$0 { pendingDuplicate = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button(L("vocab.saveAnyway")) { performSave() }
                if let existing = pendingDuplicate, let onSelectExisting {
                    Button(L("vocab.goToExisting")) {
                        pendingDuplicate = nil
                        onSelectExisting(existing)
                        dismiss()
                    }
                }
                Button(L("common.cancel"), role: .cancel) { pendingDuplicate = nil }
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

    /// Speichern-Button: bei einer Dublette in derselben Gruppe erst warnen (Dialog), sonst
    /// direkt speichern. Ein Treffer in einer anderen Gruppe ist erlaubt (nur Inline-Hinweis).
    private func attemptSave() {
        if case let .sameGroup(existing) = duplicateMatch {
            pendingDuplicate = existing
        } else {
            performSave()
        }
    }

    private func performSave() {
        pendingDuplicate = nil
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
        target.topikLevel = topikLevel
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
