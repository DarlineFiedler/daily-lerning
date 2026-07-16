import SwiftUI
import SwiftData

/// Tab 2: Liste aller Vokabelgruppen als bunte Karten mit Farbverlauf und Fortschritt.
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
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: Theme.Spacing.m) {
                            ForEach(groups) { group in
                                NavigationLink { GroupDetailView(group: group) } label: {
                                    GroupCard(group: group)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button { editingGroup = group } label: {
                                        Label(L("common.edit"), systemImage: "pencil")
                                    }
                                    Button(role: .destructive) { pendingDelete = group } label: {
                                        Label(L("common.delete"), systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .padding(Theme.Spacing.m)
                    }
                }
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle(L("tab.groups"))
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showingNew = true } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.appTitle3)
                    }
                }
            }
            .sheet(isPresented: $showingNew) { GroupEditView(group: nil) }
            .sheet(item: $editingGroup) { group in GroupEditView(group: group) }
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

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.m) {
            Image(systemName: "rectangle.stack.badge.plus")
                .font(.system(size: 56))
                .foregroundStyle(Theme.brandGradient)
            Text(L("groups.empty"))
                .font(.appBody)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button { showingNew = true } label: {
                Label(L("common.add"), systemImage: "plus")
            }
            .buttonStyle(.primary)
            .padding(.horizontal, Theme.Spacing.xl)
        }
        .padding(Theme.Spacing.l)
    }

    private func delete(_ group: VocabGroup) {
        context.delete(group)
        context.saveOrLog()
        pendingDelete = nil
        WidgetSnapshotWriter.refresh(context: context)
    }
}

/// Bunte Gruppenkarte mit Farbverlauf, Wortzahl und Fortschrittsbalken.
struct GroupCard: View {
    let group: VocabGroup

    private var learned: Int { group.count(of: .learned) }
    private var fraction: Double {
        group.vocabCount > 0 ? Double(learned) / Double(group.vocabCount) : 0
    }

    var body: some View {
        GradientCard(gradient: .forHex(group.colorHex), padding: Theme.Spacing.l) {
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                HStack {
                    Image(systemName: "rectangle.stack.fill")
                        .font(.appTitle3)
                    Text(group.name)
                        .font(.appTitle3)
                        .lineLimit(1)
                    Spacer()
                    Text(L("group.wordCount", group.vocabCount))
                        .font(.appCaption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.white.opacity(0.22), in: Capsule())
                }
                if group.vocabCount > 0 {
                    MasteryBar(fraction: fraction)
                    Text("\(learned) / \(group.vocabCount) · \(L("status.learned"))")
                        .font(.appCaption)
                        .opacity(0.9)
                }
            }
        }
    }
}

/// Schmaler weißer Fortschrittsbalken für farbige Karten.
struct MasteryBar: View {
    let fraction: Double
    var height: CGFloat = 8

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.25))
                Capsule().fill(.white)
                    .frame(width: geo.size.width * max(0, min(fraction, 1)))
            }
        }
        .frame(height: height)
    }
}

#Preview {
    GroupListView()
        .modelContainer(PersistenceController.preview)
}
