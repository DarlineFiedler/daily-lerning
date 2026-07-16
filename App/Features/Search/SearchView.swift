import SwiftUI
import SwiftData

/// Tab 2: Globale Suche über ALLE Wörter in ALLEN Gruppen (Wort oder Bedeutung).
struct SearchView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Vocab.word) private var vocabs: [Vocab]
    @State private var query = ""
    @State private var editingVocab: Vocab?
    @State private var pendingDelete: Vocab?

    private var results: [Vocab] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        return vocabs.filter {
            $0.word.matches(trimmed) || $0.meaning.matches(trimmed)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if query.trimmingCharacters(in: .whitespaces).isEmpty {
                    ContentUnavailableView {
                        Label(L("search.title"), systemImage: "magnifyingglass")
                    } description: {
                        Text(L("search.prompt"))
                    }
                } else if results.isEmpty {
                    ContentUnavailableView.search(text: query)
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
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle(L("search.title"))
            .searchable(text: $query, prompt: L("search.placeholder"))
            .sheet(item: $editingVocab) { vocab in
                VocabEditView(vocab: vocab, group: vocab.group)
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

    private func delete(_ vocab: Vocab) {
        context.delete(vocab)
        context.saveOrLog()
        pendingDelete = nil
        WidgetSnapshotWriter.refresh(context: context)
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
