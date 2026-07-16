import SwiftUI
import SwiftData

/// Detailansicht einer Gruppe: Kopf-Karte mit Fortschritt, Vokabelliste als Karten,
/// Statusfilter, Hinzufügen, Lernen starten.
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

    private var learned: Int { group.count(of: .learned) }
    private var fraction: Double {
        group.vocabCount > 0 ? Double(learned) / Double(group.vocabCount) : 0
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.m) {
                header
                if group.vocabs.isEmpty {
                    emptyState
                } else {
                    ForEach(vocabs) { vocab in
                        VocabRow(vocab: vocab) { editingVocab = vocab }
                            .cardStyle(padding: Theme.Spacing.s + 4)
                            .contextMenu {
                                Button(role: .destructive) { pendingDelete = vocab } label: {
                                    Label(L("common.delete"), systemImage: "trash")
                                }
                            }
                    }
                }
            }
            .padding(Theme.Spacing.m)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle(group.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { statusFilterMenu }
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingNew = true } label: {
                    Image(systemName: "plus.circle.fill").font(.appTitle3)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if !group.vocabs.isEmpty {
                Button { showingPractice = true } label: {
                    Label(L("practice.start"), systemImage: "play.fill")
                }
                .buttonStyle(.primary)
                .padding(Theme.Spacing.m)
                .background(.ultraThinMaterial)
            }
        }
        .sheet(isPresented: $showingNew) { VocabEditView(vocab: nil, group: group) }
        .sheet(item: $editingVocab) { vocab in VocabEditView(vocab: vocab, group: group) }
        .sheet(isPresented: $showingPractice) { PracticeConfigView(group: group) }
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

    // MARK: - Kopf-Karte

    private var header: some View {
        GradientCard(gradient: .forHex(group.colorHex), radius: 24, padding: Theme.Spacing.l) {
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                HStack {
                    Text(group.name)
                        .font(.appTitle)
                        .lineLimit(2)
                    Spacer()
                    Text(L("group.wordCount", group.vocabCount))
                        .font(.appCaption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.white.opacity(0.22), in: Capsule())
                }
                if group.vocabCount > 0 {
                    MasteryBar(fraction: fraction, height: 10)
                    Text("\(learned) / \(group.vocabCount) · \(L("status.learned"))")
                        .font(.appCaption)
                        .opacity(0.9)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.m) {
            Image(systemName: "text.book.closed")
                .font(.system(size: 48))
                .foregroundStyle(Color(hex: group.colorHex))
            Text(L("vocab.empty"))
                .font(.appBody)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button { showingNew = true } label: {
                Label(L("common.add"), systemImage: "plus")
            }
            .buttonStyle(.secondary(tint: Color(hex: group.colorHex)))
            .padding(.horizontal, Theme.Spacing.xl)
        }
        .padding(.top, Theme.Spacing.xl)
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
        context.saveOrLog()
        pendingDelete = nil
        WidgetSnapshotWriter.refresh(context: context)
    }
}
