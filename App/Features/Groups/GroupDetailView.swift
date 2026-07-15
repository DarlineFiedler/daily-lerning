import SwiftUI
import SwiftData

/// Detailansicht einer Gruppe: Vokabelliste, Statusfilter, Hinzufügen, Lernen starten.
struct GroupDetailView: View {
    @Bindable var group: VocabGroup
    @Environment(\.modelContext) private var context

    @State private var statusFilter: LearningStatus?
    @State private var showingNew = false
    @State private var editingVocab: Vocab?
    @State private var showingPractice = false
    @State private var pendingDelete: Vocab?

    private var vocabs: [Vocab] {
        group.vocabs
            .filter { statusFilter == nil || $0.status == statusFilter }
            .sorted { $0.createdAt < $1.createdAt }
    }

    var body: some View {
        Group {
            if group.vocabs.isEmpty {
                ContentUnavailableView {
                    Label(group.name, systemImage: "text.book.closed")
                } description: {
                    Text(L("vocab.empty"))
                } actions: {
                    Button(L("common.add")) { showingNew = true }
                }
            } else {
                List {
                    ForEach(vocabs) { vocab in
                        VocabRow(vocab: vocab) { editingVocab = vocab }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    pendingDelete = vocab
                                } label: {
                                    Label(L("common.delete"), systemImage: "trash")
                                }
                            }
                    }
                }
            }
        }
        .navigationTitle(group.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                statusFilterMenu
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingNew = true } label: { Image(systemName: "plus") }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if !group.vocabs.isEmpty {
                Button {
                    showingPractice = true
                } label: {
                    Label(L("practice.start"), systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .padding()
            }
        }
        .sheet(isPresented: $showingNew) {
            VocabEditView(vocab: nil, group: group)
        }
        .sheet(item: $editingVocab) { vocab in
            VocabEditView(vocab: vocab, group: group)
        }
        .sheet(isPresented: $showingPractice) {
            PracticeConfigView(group: group)
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

    private var statusFilterMenu: some View {
        Menu {
            Picker(L("vocab.status"), selection: $statusFilter) {
                Text(L("common.all")).tag(LearningStatus?.none)
                ForEach(LearningStatus.allCases) { s in
                    Label(L(s.titleKey), systemImage: s.systemImage).tag(LearningStatus?.some(s))
                }
            }
        } label: {
            Image(systemName: statusFilter == nil ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
        }
    }

    private func delete(_ vocab: Vocab) {
        context.delete(vocab)
        try? context.save()
        pendingDelete = nil
        WidgetSnapshotWriter.refresh(context: context)
    }
}
