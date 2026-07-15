import SwiftUI
import SwiftData

/// Tab 1: Liste aller Vokabelgruppen mit Farbcode und Fortschritt.
struct GroupListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \VocabGroup.sortOrder) private var groups: [VocabGroup]

    @State private var showingNew = false
    @State private var editingGroup: VocabGroup?
    @State private var pendingDelete: VocabGroup?

    var body: some View {
        NavigationStack {
            Group {
                if groups.isEmpty {
                    ContentUnavailableView {
                        Label(L("groups.title"), systemImage: "rectangle.stack")
                    } description: {
                        Text(L("groups.empty"))
                    }
                } else {
                    List {
                        ForEach(groups) { group in
                            NavigationLink {
                                GroupDetailView(group: group)
                            } label: {
                                GroupRow(group: group)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    pendingDelete = group
                                } label: {
                                    Label(L("common.delete"), systemImage: "trash")
                                }
                                Button {
                                    editingGroup = group
                                } label: {
                                    Label(L("common.edit"), systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle(L("tab.groups"))
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showingNew = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingNew) {
                GroupEditView(group: nil)
            }
            .sheet(item: $editingGroup) { group in
                GroupEditView(group: group)
            }
            .confirmationDialog(
                L("group.deleteConfirm"),
                isPresented: Binding(
                    get: { pendingDelete != nil },
                    set: { if !$0 { pendingDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button(L("common.delete"), role: .destructive) {
                    if let group = pendingDelete { delete(group) }
                }
                Button(L("common.cancel"), role: .cancel) { pendingDelete = nil }
            }
        }
    }

    private func delete(_ group: VocabGroup) {
        context.delete(group)
        try? context.save()
        pendingDelete = nil
        WidgetSnapshotWriter.refresh(context: context)
    }
}

/// Eine Zeile in der Gruppenliste.
struct GroupRow: View {
    let group: VocabGroup

    private var counts: [LearningStatus: Int] {
        Dictionary(uniqueKeysWithValues: LearningStatus.allCases.map { ($0, group.count(of: $0)) })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                GroupColorDot(colorHex: group.colorHex, size: 16)
                Text(group.name)
                    .font(.headline)
                Spacer()
                Text(L("group.wordCount", group.vocabCount))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if group.vocabCount > 0 {
                StatusDistributionBar(counts: counts)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    GroupListView()
        .modelContainer(PersistenceController.preview)
}
