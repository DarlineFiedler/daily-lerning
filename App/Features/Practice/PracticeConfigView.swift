import SwiftUI
import SwiftData

/// Konfiguriert einen Lernvorgang für eine Gruppe (Status-Filter, Richtung, Modi).
struct PracticeConfigView: View {
    let group: VocabGroup
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var selectedStatuses: Set<LearningStatus> = []
    @State private var direction: PracticeDirection = .wordToMeaning
    @State private var selectedModes: Set<PracticeMode> = []
    @State private var startSession = false

    /// Wörter, die zur aktuellen Auswahl passen (leere Statusmenge = alle).
    private var pool: [Vocab] {
        group.vocabs.filter {
            selectedStatuses.isEmpty || selectedStatuses.contains($0.status)
        }
    }

    private var config: PracticeConfig {
        PracticeConfig(statuses: selectedStatuses, direction: direction, modes: selectedModes)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                    statusSection
                    directionSection
                    modeSection
                }
                .padding(Theme.Spacing.m)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle(L("practice.config.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("common.cancel")) { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) { startBar }
            .navigationDestination(isPresented: $startSession) {
                PracticeContainerView(
                    session: PracticeSession(
                        vocabs: pool,
                        distractorPool: group.vocabs,
                        config: config,
                        context: context
                    ),
                    onClose: { dismiss() }
                )
            }
        }
    }

    // MARK: - Abschnitte

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            SectionHeader(L("practice.config.statuses"))
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
            Text(L("common.all"))
                .font(.appCaption)
                .foregroundStyle(.secondary)
                .opacity(selectedStatuses.isEmpty ? 1 : 0.4)
        }
    }

    private var directionSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            SectionHeader(L("practice.config.direction"))
            Picker(L("practice.config.direction"), selection: $direction) {
                ForEach(PracticeDirection.allCases) { dir in
                    Text(L(dir.titleKey)).tag(dir)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var modeSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            SectionHeader(L("practice.config.modes"))
            FlowChips {
                ForEach(PracticeMode.allCases) { mode in
                    SelectableChip(
                        title: L(mode.titleKey),
                        systemImage: mode.systemImage,
                        tint: Theme.brandStart,
                        isSelected: selectedModes.contains(mode)
                    ) { toggle(&selectedModes, mode) }
                }
            }
            Text(L("practice.config.modesHint"))
                .font(.appCaption)
                .foregroundStyle(.secondary)
        }
    }

    private var startBar: some View {
        VStack(spacing: 6) {
            Button { startSession = true } label: {
                Label(L("common.start"), systemImage: "play.fill")
            }
            .buttonStyle(.primary)
            .disabled(pool.isEmpty)

            Text(L("group.wordCount", pool.count))
                .font(.appCaption)
                .foregroundStyle(pool.isEmpty ? .red : .secondary)
        }
        .padding(Theme.Spacing.m)
        .background(.ultraThinMaterial)
    }

    private func toggle<T: Hashable>(_ set: inout Set<T>, _ value: T) {
        if set.contains(value) { set.remove(value) } else { set.insert(value) }
    }
}

/// Einfaches umbrechendes Chip-Layout (WrapLayout) für die Auswahl-Chips.
struct FlowChips<Content: View>: View {
    @ViewBuilder var content: () -> Content
    var body: some View {
        WrapLayout(spacing: Theme.Spacing.s) { content() }
    }
}

/// Layout, das Kinder horizontal anordnet und bei Platzmangel umbricht.
struct WrapLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth == .infinity ? x : maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
