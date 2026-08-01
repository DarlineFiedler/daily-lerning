import SwiftData
import SwiftUI

/// Wiederverwendbare Wörter-Liste über ALLE aktiven Gruppen – geöffnet aus den
/// Fortschritts-Kacheln im Home-Dashboard. Layout wie `GroupDetailView` (Karten),
/// mit Suchfeld statt Gruppen-Kopf und optionalem Status-Filter.
///
/// Zwei Modi über `lockedStatus`:
/// - `nil` → alle Wörter, Status-Filter-Chips sichtbar (Kachel „Wörter").
/// - z.B. `.learned` → fest auf diesen Status eingeschränkt, keine Chips (Kachel „Gelernt").
struct WordListView: View {
    let titleKey: String
    var lockedStatus: LearningStatus?

    @Environment(\.modelContext) private var context
    @Query(sort: \Vocab.word) private var vocabs: [Vocab]

    @State private var query = ""
    @State private var selectedStatuses: Set<LearningStatus> = []
    @State private var editingVocab: Vocab?
    @State private var pendingDelete: Vocab?

    /// Nur nicht-archivierte Wörter (wie `HomeView.activeVocabs`), damit die Liste
    /// zu den Kachel-Zahlen passt.
    private var activeVocabs: [Vocab] {
        vocabs.filter { $0.group?.isArchived != true }
    }

    /// Text- und Statusfilter kombiniert. Bei `lockedStatus` ist der Status fix,
    /// sonst greifen die (optional gewählten) Filter-Chips.
    private var results: [Vocab] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return activeVocabs.filter { matchesStatus($0) && matchesText($0, trimmed) }
    }

    private func matchesStatus(_ vocab: Vocab) -> Bool {
        if let locked = lockedStatus { return vocab.status == locked }
        return selectedStatuses.isEmpty || selectedStatuses.contains(vocab.status)
    }

    private func matchesText(_ vocab: Vocab, _ trimmed: String) -> Bool {
        trimmed.isEmpty || vocab.word.matches(trimmed) || vocab.meaning.matches(trimmed)
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: Theme.Spacing.m) {
                if lockedStatus == nil, !activeVocabs.isEmpty { filterChips }
                if results.isEmpty {
                    emptyState
                } else {
                    ForEach(results) { vocab in
                        VocabRow(vocab: vocab, showGroup: true) { editingVocab = vocab }
                            .cardStyle(padding: Theme.Spacing.s + 4)
                            .contextMenu { rowMenu(vocab) }
                    }
                }
            }
            .padding(Theme.Spacing.m)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle(L(titleKey))
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, prompt: L("search.placeholder"))
        .sheet(item: $editingVocab) { vocab in
            VocabEditView(vocab: vocab, group: vocab.group) { existing in
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

    // MARK: - Bausteine

    private var filterChips: some View {
        FlowChips {
            ForEach(LearningStatus.allCases) { status in
                SelectableChip(
                    title: L(status.titleKey),
                    systemImage: status.systemImage,
                    tint: status.color,
                    isSelected: selectedStatuses.contains(status)
                ) { toggle(&selectedStatuses, status) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func rowMenu(_ vocab: Vocab) -> some View {
        Button { editingVocab = vocab } label: {
            Label(L("common.edit"), systemImage: "pencil")
        }
        Button(role: .destructive) { pendingDelete = vocab } label: {
            Label(L("common.delete"), systemImage: "trash")
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label(L("search.empty"), systemImage: "magnifyingglass")
        }
        .padding(.top, Theme.Spacing.xl)
    }

    // MARK: - Aktionen

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
    /// Groß-/Kleinschreibung- und diakritika-unempfindlicher Teilstring-Vergleich
    /// (wie in `SearchView`).
    func matches(_ term: String) -> Bool {
        range(of: term, options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }
}

#Preview {
    NavigationStack {
        WordListView(titleKey: "words.all.title")
    }
    .modelContainer(PersistenceController.preview)
}
