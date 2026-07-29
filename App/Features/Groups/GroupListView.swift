import SwiftData
import SwiftUI

/// Tab 2: Liste aller Vokabelgruppen als bunte Karten mit Farbverlauf und Fortschritt.
struct GroupListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \VocabGroup.sortOrder) private var groups: [VocabGroup]

    @State private var showingNew = false
    @State private var editingGroup: VocabGroup?
    @State private var pendingDelete: VocabGroup?
    @State private var showArchived = false

    /// Aktive Gruppen (Standardansicht) vs. archivierte (eigener, eingeklappter Bereich).
    private var activeGroups: [VocabGroup] { groups.filter { !$0.isArchived } }
    private var archivedGroups: [VocabGroup] { groups.filter { $0.isArchived } }

    var body: some View {
        NavigationStack {
            Group {
                if groups.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: Theme.Spacing.m) {
                            ForEach(activeGroups) { group in
                                groupRow(group)
                            }
                            if !archivedGroups.isEmpty {
                                archivedSection
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
                    .accessibilityLabel(L("group.new"))
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

    /// Eine Gruppenkarte mit Navigation und Kontextmenü. Archivierte Karten werden
    /// abgedunkelt dargestellt; aktive Karten lassen sich per Drag & Drop umsortieren.
    @ViewBuilder
    private func groupRow(_ group: VocabGroup) -> some View {
        let card = NavigationLink { GroupDetailView(group: group) } label: {
            GroupCard(group: group)
                .opacity(group.isArchived ? 0.55 : 1)
        }
        .buttonStyle(.plain)
        .contextMenu { contextMenu(for: group) }

        if group.isArchived {
            card
        } else {
            card
                .draggable(group.id.uuidString) {
                    GroupCard(group: group).frame(width: 260).opacity(0.9)
                }
                .dropDestination(for: String.self) { items, _ in
                    guard let first = items.first, let dragged = UUID(uuidString: first) else {
                        return false
                    }
                    applyReorder(moving: dragged, toPositionOf: group.id)
                    return true
                }
        }
    }

    @ViewBuilder
    private func contextMenu(for group: VocabGroup) -> some View {
        Button { editingGroup = group } label: {
            Label(L("common.edit"), systemImage: "pencil")
        }
        if group.isArchived {
            Button { setArchived(group, false) } label: {
                Label(L("group.reactivate"), systemImage: "arrow.uturn.up")
            }
        } else {
            if group.id != activeGroups.first?.id {
                Button { move(group, by: -1) } label: {
                    Label(L("group.moveUp"), systemImage: "arrow.up")
                }
            }
            if group.id != activeGroups.last?.id {
                Button { move(group, by: 1) } label: {
                    Label(L("group.moveDown"), systemImage: "arrow.down")
                }
            }
            Button { setArchived(group, true) } label: {
                Label(L("group.archive"), systemImage: "archivebox")
            }
        }
        Button(role: .destructive) { pendingDelete = group } label: {
            Label(L("common.delete"), systemImage: "trash")
        }
    }

    /// Eingeklappter Bereich mit den archivierten Gruppen.
    private var archivedSection: some View {
        DisclosureGroup(isExpanded: $showArchived) {
            LazyVStack(spacing: Theme.Spacing.m) {
                ForEach(archivedGroups) { group in
                    groupRow(group)
                }
            }
            .padding(.top, Theme.Spacing.s)
        } label: {
            Label(L("group.archivedSection", archivedGroups.count), systemImage: "archivebox.fill")
                .font(.appHeadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, Theme.Spacing.m)
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
        AppContentRefresh.afterVocabChange(context: context)
    }

    /// Archiviert bzw. reaktiviert eine Gruppe. Da sich damit die aktiven Wörter
    /// (Übung/Widget/Badge) ändern, werden Snapshot und Badge aufgefrischt.
    /// Beim Reaktivieren wird die aktive Reihenfolge neu (0…n) durchnummeriert und
    /// die Gruppe ans Ende gesetzt – sonst könnte ihr eingefrorener `sortOrder` mit
    /// einem der (durch Drag & Drop) neu vergebenen aktiven Werte kollidieren.
    private func setArchived(_ group: VocabGroup, _ archived: Bool) {
        group.isArchived = archived
        if !archived { renumberActiveOrder(bringingToEnd: group) }
        context.saveOrLog()
        AppContentRefresh.afterVocabChange(context: context)
    }

    /// Vergibt lückenlose `sortOrder`-Werte (0…n) an alle aktiven Gruppen in ihrer
    /// aktuellen Reihenfolge. `bringingToEnd` schiebt eine Gruppe ans Ende (z.B. die
    /// gerade reaktivierte). Hält `sortOrder` eindeutig, auch nachdem archivierte
    /// Gruppen ihre alten Werte behalten haben.
    private func renumberActiveOrder(bringingToEnd last: VocabGroup? = nil) {
        let active = groups.filter { !$0.isArchived }
        let order = Self.renumberedOrder(active.map { ($0.id, $0.sortOrder) }, bringingToEnd: last?.id)
        let byID = Dictionary(uniqueKeysWithValues: active.map { ($0.id, $0) })
        for (index, id) in order.enumerated() where byID[id]?.sortOrder != index {
            byID[id]?.sortOrder = index
        }
    }

    /// Reine Reihenfolge-Logik hinter `renumberActiveOrder`: sortiert die
    /// (id, sortOrder)-Paare, schiebt optional eine id ans Ende und liefert die neue
    /// id-Folge – die Index-Position ist der neue, garantiert eindeutige `sortOrder`.
    /// Ausgelagert & `static`, damit die Logik testbar ist.
    static func renumberedOrder(_ groups: [(id: UUID, sortOrder: Int)], bringingToEnd last: UUID?) -> [UUID] {
        var ordered = groups.sorted { $0.sortOrder < $1.sortOrder }.map(\.id)
        if let last, let idx = ordered.firstIndex(of: last) {
            ordered.append(ordered.remove(at: idx))
        }
        return ordered
    }

    /// Verschiebt eine aktive Gruppe um `offset` Positionen (tauscht `sortOrder` mit
    /// dem Nachbarn innerhalb der aktiven Liste). Accessibility-Fallback zum Drag & Drop
    /// (VoiceOver), wo Ziehen umständlich ist.
    private func move(_ group: VocabGroup, by offset: Int) {
        let list = activeGroups
        guard let idx = list.firstIndex(where: { $0.id == group.id }) else { return }
        let target = idx + offset
        guard list.indices.contains(target) else { return }
        let other = list[target]
        let tmp = group.sortOrder
        group.sortOrder = other.sortOrder
        other.sortOrder = tmp
        context.saveOrLog()
    }

    /// Wendet eine Drag-&-Drop-Neuordnung an: Das gezogene Element rückt an die
    /// Position des Ziel-Elements, danach werden ALLE aktiven Gruppen neu (0…n)
    /// durchnummeriert – so bleibt `sortOrder` konsistent statt nur zwei zu tauschen.
    private func applyReorder(moving draggedID: UUID, toPositionOf targetID: UUID) {
        let newOrder = Self.reordered(activeGroups.map(\.id), moving: draggedID, toPositionOf: targetID)
        let byID = Dictionary(uniqueKeysWithValues: activeGroups.map { ($0.id, $0) })
        for (index, id) in newOrder.enumerated() where byID[id]?.sortOrder != index {
            byID[id]?.sortOrder = index
        }
        context.saveOrLog()
    }

    /// Pure Neuordnung einer id-Liste: das gezogene Element wird an die Position des
    /// Ziel-Elements gesetzt. Ausgelagert & `static`, damit die Logik testbar ist.
    static func reordered(_ ids: [UUID], moving draggedID: UUID, toPositionOf targetID: UUID) -> [UUID] {
        guard draggedID != targetID else { return ids }
        var order = ids
        guard let from = order.firstIndex(of: draggedID) else { return ids }
        let moved = order.remove(at: from)
        guard let to = order.firstIndex(of: targetID) else { return ids }
        order.insert(moved, at: to)
        return order
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
