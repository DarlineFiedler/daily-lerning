import SwiftData
import SwiftUI

/// Tab 2: Globale Suche über ALLE Wörter in ALLEN Gruppen (Wort oder Bedeutung).
struct SearchView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Vocab.word) private var vocabs: [Vocab]
    @Query(sort: \VocabGroup.sortOrder) private var groups: [VocabGroup]
    @State private var query = ""
    @State private var editingVocab: Vocab?
    @State private var pendingDelete: Vocab?
    /// Zusätzliche Filter (Mehrfachauswahl). Leere Menge = keine Einschränkung.
    /// Bewusst pro Öffnen zurückgesetzt (nicht persistiert).
    @State private var selectedGroups: Set<UUID> = []
    @State private var selectedStatuses: Set<LearningStatus> = []

    private var results: [Vocab] {
        Self.filter(vocabs, query: query, groups: selectedGroups, statuses: selectedStatuses)
    }

    /// Ist überhaupt eine Eingrenzung aktiv (Text ODER Gruppe ODER Status)?
    private var hasCriteria: Bool {
        !query.trimmingCharacters(in: .whitespaces).isEmpty
            || !selectedGroups.isEmpty || !selectedStatuses.isEmpty
    }

    /// Kombinierte Filterung: Textmatch UND Gruppenfilter UND Statusfilter, jeweils
    /// leere Menge = keine Einschränkung. Ohne jegliche Kriterien leer (Startzustand).
    /// Pure & `static`, damit die Logik testbar ist.
    static func filter(_ vocabs: [Vocab], query: String,
                       groups: Set<UUID>, statuses: Set<LearningStatus>) -> [Vocab] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty || !groups.isEmpty || !statuses.isEmpty else { return [] }
        return vocabs.filter { vocab in
            (trimmed.isEmpty || vocab.word.matches(trimmed) || vocab.meaning.matches(trimmed))
                && (groups.isEmpty || (vocab.group.map { groups.contains($0.id) } ?? false))
                && (statuses.isEmpty || statuses.contains(vocab.status))
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: Theme.Spacing.s) {
                if !vocabs.isEmpty { filterBar }
                content
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle(L("search.title"))
            .searchable(text: $query, prompt: L("search.placeholder"))
            .onChange(of: query) { _, newValue in
                // Erste echte Sucheingabe schaltet das „Spürnase"-Badge frei.
                if !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    AchievementService.recordEvent(\.searchUsed, context: context)
                }
            }
            .sheet(item: $editingVocab) { vocab in
                VocabEditView(vocab: vocab, group: vocab.group) { existing in
                    // Der Editor schließt sich selbst (`dismiss`), was die item-Bindung auf
                    // nil zurücksetzt. Den Sprung zur bestehenden Vokabel daher nachziehen,
                    // sobald das aktuelle Sheet zu ist – sonst wird der Wechsel verschluckt.
                    DispatchQueue.main.async { editingVocab = existing }
                }
            }
            .confirmationDialog(
                L("vocab.deleteConfirm"),
                isPresented: Binding(
                    get: { pendingDelete != nil },
                    set: { if !$0 { pendingDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button(L("common.delete"), role: .destructive) {
                    if let vocab = pendingDelete { delete(vocab) }
                }
                Button(L("common.cancel"), role: .cancel) { pendingDelete = nil }
            }
        }
    }

    // MARK: - Filter-Chips

    /// Immer sichtbare Filter-Chips (Status + Gruppe, Mehrfachauswahl). Erlaubt auch
    /// ohne Suchbegriff ein reines Browsen nach Gruppe/Status.
    ///
    /// Bewusst je Kriterium eine eigene, horizontal scrollende Zeile: Bei vielen
    /// Gruppen würde ein umbrechendes Chip-Feld sonst fast den ganzen Bildschirm
    /// füllen und die Trefferliste verdrängen.
    private var filterBar: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            chipRow(title: L("search.filter.status"), selectedCount: selectedStatuses.count) {
                ForEach(LearningStatus.allCases) { status in
                    SelectableChip(
                        title: L(status.titleKey),
                        systemImage: status.systemImage,
                        tint: status.color,
                        isSelected: selectedStatuses.contains(status)
                    ) { toggle(&selectedStatuses, status) }
                }
            }
            if groups.count > 1 {
                chipRow(title: L("search.filter.groups"), selectedCount: selectedGroups.count) {
                    ForEach(groups) { group in
                        SelectableChip(
                            title: group.name,
                            systemImage: "rectangle.stack.fill",
                            tint: Color(hex: group.colorHex),
                            isSelected: selectedGroups.contains(group.id)
                        ) { toggle(&selectedGroups, group.id) }
                    }
                }
            }
        }
        .padding(.top, Theme.Spacing.s)
    }

    /// Eine beschriftete Filterzeile: kleines Label (mit optionaler Auswahl-Anzahl)
    /// über einer horizontal scrollenden Chip-Reihe.
    @ViewBuilder
    private func chipRow(
        title: String,
        selectedCount: Int,
        @ViewBuilder chips: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.appCaption.weight(.semibold))
                    .textCase(.uppercase)
                if selectedCount > 0 {
                    Text("\(selectedCount)")
                        .font(.appCaption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, Theme.Spacing.xs / 2)
                        .background(Capsule().fill(Theme.brandStart))
                }
            }
            .foregroundStyle(.secondary)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                selectedCount > 0
                    ? "\(title), \(selectedCount) \(L("search.filter.selectedSuffix"))"
                    : title
            )
            .padding(.horizontal, Theme.Spacing.m)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.s) { chips() }
                    .padding(.horizontal, Theme.Spacing.m)
                    .padding(.vertical, 2)
            }
        }
    }

    // MARK: - Inhalt

    @ViewBuilder
    private var content: some View {
        if !hasCriteria {
            ContentUnavailableView {
                Label(L("search.title"), systemImage: "magnifyingglass")
            } description: {
                Text(L("search.prompt"))
            }
        } else if results.isEmpty {
            ContentUnavailableView {
                Label(L("search.empty"), systemImage: "magnifyingglass")
            }
        } else {
            List {
                ForEach(results) { vocab in
                    VocabRow(vocab: vocab, showGroup: true) {
                        editingVocab = vocab
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) { pendingDelete = vocab } label: {
                            Label(L("common.delete"), systemImage: "trash")
                        }
                        Button { editingVocab = vocab } label: {
                            Label(L("common.edit"), systemImage: "pencil")
                        }
                        .tint(.accentColor)
                    }
                }
            }
            .scrollContentBackground(.hidden)
        }
    }

    private func toggle<T: Hashable>(_ set: inout Set<T>, _ value: T) {
        if set.contains(value) { set.remove(value) } else { set.insert(value) }
    }

    private func delete(_ vocab: Vocab) {
        context.delete(vocab)
        context.saveOrLog()
        pendingDelete = nil
        AppContentRefresh.afterVocabChange(context: context)
    }
}

private extension String {
    /// Groß-/Kleinschreibung- und diakritika-unempfindlicher Teilstring-Vergleich.
    func matches(_ term: String) -> Bool {
        range(of: term, options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }
}

#Preview {
    SearchView()
        .modelContainer(PersistenceController.preview)
}
