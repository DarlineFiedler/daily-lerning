import SwiftData
import SwiftUI

/// Detailansicht einer Gruppe: Kopf-Karte mit Fortschritt, Vokabelliste als Karten,
/// Status-Filter-Chips (Mehrfachauswahl), Hinzufügen, Lernen starten. Über den
/// Auswahl-Modus lassen sich mehrere Wörter markieren und ihr Status setzen oder
/// zurücksetzen; einzeln und gruppenweit geht das ebenfalls.
struct GroupDetailView: View {
    @Bindable var group: VocabGroup
    @Environment(\.modelContext) private var context

    @State private var selectedStatuses: Set<LearningStatus> = []
    @State private var showingNew = false
    @State private var editingVocab: Vocab?
    @State private var showingPractice = false
    @State private var pendingDelete: Vocab?

    @State private var isSelecting = false
    @State private var selection: Set<UUID> = []
    @State private var showingResetGroup = false
    @State private var pendingResetVocab: Vocab?

    private var vocabs: [Vocab] {
        group.vocabs
            .filter { selectedStatuses.isEmpty || selectedStatuses.contains($0.status) }
            .sorted { $0.createdAt < $1.createdAt }
    }

    private var selectedVocabs: [Vocab] {
        group.vocabs.filter { selection.contains($0.id) }
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
                    filterChips
                    ForEach(vocabs) { vocab in
                        row(vocab)
                    }
                }
            }
            .padding(Theme.Spacing.m)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle(group.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .safeAreaInset(edge: .bottom) { bottomBar }
        .sheet(isPresented: $showingNew) { VocabEditView(vocab: nil, group: group) }
        .sheet(item: $editingVocab) { vocab in VocabEditView(vocab: vocab, group: group) }
        .sheet(isPresented: $showingPractice) { PracticeConfigView() }
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
        .confirmationDialog(
            L("vocab.resetConfirm"),
            isPresented: Binding(
                get: { pendingResetVocab != nil },
                set: { if !$0 { pendingResetVocab = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(L("common.reset"), role: .destructive) {
                if let vocab = pendingResetVocab { apply(.new, to: [vocab]) }
                pendingResetVocab = nil
            }
            Button(L("common.cancel"), role: .cancel) { pendingResetVocab = nil }
        }
        .confirmationDialog(
            L("group.resetAllConfirm"),
            isPresented: $showingResetGroup,
            titleVisibility: .visible
        ) {
            Button(L("common.reset"), role: .destructive) { apply(.new, to: group.vocabs) }
            Button(L("common.cancel"), role: .cancel) {}
        }
    }

    // MARK: - Zeile

    @ViewBuilder
    private func row(_ vocab: Vocab) -> some View {
        let card = VocabRow(
            vocab: vocab,
            isSelecting: isSelecting,
            isSelected: selection.contains(vocab.id)
        ) {
            if isSelecting {
                toggle(&selection, vocab.id)
            } else {
                editingVocab = vocab
            }
        }
        .cardStyle(padding: Theme.Spacing.s + 4)

        if isSelecting {
            card
        } else {
            card.contextMenu { rowMenu(vocab) }
        }
    }

    @ViewBuilder
    private func rowMenu(_ vocab: Vocab) -> some View {
        Button { editingVocab = vocab } label: {
            Label(L("common.edit"), systemImage: "pencil")
        }
        Menu {
            ForEach(LearningStatus.allCases) { status in
                Button { apply(status, to: [vocab]) } label: {
                    Label(L(status.titleKey), systemImage: status.systemImage)
                }
            }
        } label: {
            Label(L("vocab.changeStatus"), systemImage: "arrow.triangle.2.circlepath")
        }
        Button { pendingResetVocab = vocab } label: {
            Label(L("common.reset"), systemImage: "arrow.counterclockwise")
        }
        Button(role: .destructive) { pendingDelete = vocab } label: {
            Label(L("common.delete"), systemImage: "trash")
        }
    }

    // MARK: - Toolbar & untere Leiste

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if isSelecting {
            ToolbarItem(placement: .topBarLeading) {
                Button(L("common.cancel")) { exitSelection() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(L("common.selectAll")) { toggleSelectAll() }
            }
        } else {
            if !group.vocabs.isEmpty {
                ToolbarItem(placement: .topBarTrailing) { overflowMenu }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingNew = true } label: {
                    Image(systemName: "plus.circle.fill").font(.appTitle3)
                }
            }
        }
    }

    private var overflowMenu: some View {
        Menu {
            Button { isSelecting = true } label: {
                Label(L("common.select"), systemImage: "checkmark.circle")
            }
            Button(role: .destructive) { showingResetGroup = true } label: {
                Label(L("group.resetAll"), systemImage: "arrow.counterclockwise")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
    }

    @ViewBuilder
    private var bottomBar: some View {
        if isSelecting {
            selectionBar
        } else if !group.vocabs.isEmpty {
            Button { showingPractice = true } label: {
                Label(L("practice.start"), systemImage: "play.fill")
            }
            .buttonStyle(.primary)
            .padding(Theme.Spacing.m)
            .background(.ultraThinMaterial)
        }
    }

    private var selectionBar: some View {
        HStack(spacing: Theme.Spacing.m) {
            Text(L("vocab.selectedCount", selection.count))
                .font(.appSubheadline.weight(.semibold))
            Spacer()
            Menu {
                ForEach(LearningStatus.allCases) { status in
                    Button { apply(status, to: selectedVocabs) } label: {
                        Label(L(status.titleKey), systemImage: status.systemImage)
                    }
                }
            } label: {
                Label(L("vocab.setStatus"), systemImage: "circle.lefthalf.filled")
            }
            Button { apply(.new, to: selectedVocabs) } label: {
                Label(L("common.reset"), systemImage: "arrow.counterclockwise")
            }
        }
        .font(.appSubheadline.weight(.medium))
        .disabled(selection.isEmpty)
        .padding(Theme.Spacing.m)
        .background(.ultraThinMaterial)
    }

    // MARK: - Kopf-Karte & Filter

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

    // MARK: - Aktionen

    private func toggle<T: Hashable>(_ set: inout Set<T>, _ value: T) {
        if set.contains(value) { set.remove(value) } else { set.insert(value) }
    }

    private func toggleSelectAll() {
        let ids = Set(vocabs.map(\.id))
        if selection.isSuperset(of: ids) {
            selection.subtract(ids)
        } else {
            selection.formUnion(ids)
        }
    }

    private func exitSelection() {
        isSelecting = false
        selection.removeAll()
    }

    /// Setzt den Status für die übergebenen Wörter (inkl. Zähler & Wiederholungsplan
    /// über `setStatusManually`), speichert einmalig und verlässt den Auswahl-Modus.
    private func apply(_ status: LearningStatus, to targets: [Vocab]) {
        for vocab in targets { vocab.setStatusManually(status) }
        context.saveOrLog()
        WidgetSnapshotWriter.refresh(context: context)
        exitSelection()
    }

    private func delete(_ vocab: Vocab) {
        context.delete(vocab)
        context.saveOrLog()
        pendingDelete = nil
        WidgetSnapshotWriter.refresh(context: context)
    }
}
