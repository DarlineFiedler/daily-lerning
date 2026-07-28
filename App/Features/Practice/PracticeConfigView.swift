import SwiftData
import SwiftUI

/// Konfiguriert einen Lernvorgang (Gruppen-Auswahl, Status-Filter, Richtung, Modi).
struct PracticeConfigView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(ActiveSessionStore.self) private var sessionStore
    @Query(sort: \VocabGroup.sortOrder) private var allGroups: [VocabGroup]

    @State private var selectedGroupIDs: Set<UUID>
    @State private var selectedStatuses: Set<LearningStatus> = []
    @State private var selectedTopikLevels: Set<TopikLevel> = []
    @State private var problemsOnly: Bool
    @State private var direction: PracticeDirection = .wordToMeaning
    @State private var selectedModes: Set<PracticeMode> = []
    @State private var wordLimit: Int?
    @State private var startSession = false

    @State private var presets: [PracticePreset] = []
    @State private var showingSavePreset = false
    @State private var newPresetName = ""

    /// `preselected` sind die beim Öffnen bereits gewählten Gruppen. Standardmäßig
    /// leer – leere Auswahl bedeutet „alle Gruppen" (siehe `resolvedGroups`).
    /// `problemsOnly` legt den Fokus-Filter vorab an (z.B. vom „Problemwörter"-Button
    /// in der Gruppen-Detailansicht aus).
    init(preselected: [VocabGroup] = [], problemsOnly: Bool = false) {
        _selectedGroupIDs = State(initialValue: Set(preselected.map(\.id)))
        _problemsOnly = State(initialValue: problemsOnly)
    }

    /// Nur nicht-archivierte Gruppen stehen zum Üben zur Auswahl – archivierte
    /// Gruppen sind pausiert (siehe [[VocabGroup]] `isArchived`).
    private var activeGroups: [VocabGroup] {
        allGroups.filter { !$0.isArchived }
    }

    /// Tatsächlich verwendete Gruppen: leere Auswahl = alle (aktiven) Gruppen.
    private var resolvedGroups: [VocabGroup] {
        selectedGroupIDs.isEmpty ? activeGroups : activeGroups.filter { selectedGroupIDs.contains($0.id) }
    }

    /// Wörter, die zur aktuellen Auswahl passen. Leere Status- bzw. TOPIK-Menge = alle.
    /// Bei aktivem TOPIK-Filter fallen nicht eingestufte Wörter (`topikLevel == nil`) weg.
    /// Ist der Fokus „Problemwörter" aktiv, bleiben nur auffällige Wörter (siehe
    /// `Vocab.isProblemWord`).
    private var pool: [Vocab] {
        resolvedGroups.flatMap(\.vocabs).filter {
            (selectedStatuses.isEmpty || selectedStatuses.contains($0.status)) &&
                (selectedTopikLevels.isEmpty || $0.topikLevel.map(selectedTopikLevels.contains) ?? false) &&
                (!problemsOnly || $0.isProblemWord)
        }
    }

    /// So viele Wörter werden tatsächlich abgefragt (Begrenzung berücksichtigt).
    private var effectiveCount: Int {
        min(pool.count, wordLimit ?? pool.count)
    }

    private var config: PracticeConfig {
        PracticeConfig(statuses: selectedStatuses, direction: direction,
                       modes: selectedModes, wordLimit: wordLimit)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                    if !presets.isEmpty { presetSection }
                    if activeGroups.count > 1 { groupSection }
                    statusSection
                    topikSection
                    focusSection
                    DirectionModeSelection(direction: $direction, modes: $selectedModes)
                    WordLimitSelection(wordLimit: $wordLimit)
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
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        newPresetName = ""
                        showingSavePreset = true
                    } label: {
                        Label(L("practice.config.savePreset"), systemImage: "square.and.arrow.down")
                    }
                    .disabled(pool.isEmpty)
                }
            }
            .safeAreaInset(edge: .bottom) { startBar }
            .navigationDestination(isPresented: $startSession) {
                PracticeContainerView(
                    session: PracticeSession(
                        vocabs: pool,
                        distractorPool: resolvedGroups.flatMap(\.vocabs),
                        config: config,
                        context: context
                    ),
                    onClose: { dismiss() },
                    // Gruppen-Fluss läuft in der Navigation weiter; ein Live-Activity-Tap
                    // bringt die App in den Vordergrund (nicht wieder-präsentierbar).
                    sessionStore: sessionStore,
                    resumable: false
                )
            }
            .onAppear { presets = PracticePresetStore.all() }
            .alert(L("practice.config.savePreset"), isPresented: $showingSavePreset) {
                TextField(L("practice.preset.namePrompt"), text: $newPresetName)
                Button(L("common.cancel"), role: .cancel) {}
                Button(L("common.save")) { savePreset() }
            } message: {
                Text(L("practice.preset.namePrompt"))
            }
        }
    }

    // MARK: - Abschnitte

    private var groupSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            SectionHeader(L("practice.config.groups"))
            FlowChips {
                SelectableChip(
                    title: L("practice.config.allGroups"),
                    systemImage: "square.stack.3d.up.fill",
                    tint: Theme.brandStart,
                    isSelected: selectedGroupIDs.isEmpty
                ) { selectedGroupIDs = [] }
                ForEach(activeGroups) { group in
                    SelectableChip(
                        title: group.name,
                        systemImage: "rectangle.stack.fill",
                        tint: Color(hex: group.colorHex),
                        isSelected: selectedGroupIDs.contains(group.id)
                    ) { toggle(&selectedGroupIDs, group.id) }
                }
            }
        }
    }

    private var presetSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            SectionHeader(L("practice.config.presets"))
            FlowChips {
                ForEach(presets) { preset in
                    SelectableChip(
                        title: preset.name,
                        systemImage: "slider.horizontal.3",
                        tint: Theme.brandEnd,
                        isSelected: false
                    ) { apply(preset) }
                    .contextMenu {
                        Button(role: .destructive) { delete(preset) } label: {
                            Label(L("common.delete"), systemImage: "trash")
                        }
                    }
                }
            }
        }
    }

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

    private var topikSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            SectionHeader(L("practice.config.topik"))
            FlowChips {
                ForEach(TopikLevel.allCases) { level in
                    SelectableChip(
                        title: L(level.titleKey),
                        systemImage: "graduationcap.fill",
                        tint: Theme.brandStart,
                        isSelected: selectedTopikLevels.contains(level)
                    ) { toggle(&selectedTopikLevels, level) }
                }
            }
            Text(L("common.all"))
                .font(.appCaption)
                .foregroundStyle(.secondary)
                .opacity(selectedTopikLevels.isEmpty ? 1 : 0.4)
        }
    }

    private var focusSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            SectionHeader(L("practice.config.focus"))
            FlowChips {
                SelectableChip(
                    title: L("practice.problems.title"),
                    systemImage: "exclamationmark.triangle.fill",
                    tint: Theme.wrong,
                    isSelected: problemsOnly
                ) { problemsOnly.toggle() }
            }
        }
    }

    private var startBar: some View {
        VStack(spacing: 6) {
            Button { startSession = true } label: {
                Label(L("common.start"), systemImage: "play.fill")
            }
            .buttonStyle(.primary)
            .disabled(pool.isEmpty)

            Text(L("group.wordCount", effectiveCount))
                .font(.appCaption)
                .foregroundStyle(pool.isEmpty ? Theme.wrong : .secondary)
        }
        .padding(Theme.Spacing.m)
        .background(.ultraThinMaterial)
    }

    private func toggle<T: Hashable>(_ set: inout Set<T>, _ value: T) {
        if set.contains(value) { set.remove(value) } else { set.insert(value) }
    }

    // MARK: - Voreinstellungen

    /// Speichert die aktuelle Konfiguration als benanntes Preset. Ein bestehendes
    /// Preset mit gleichem Namen (Groß-/Kleinschreibung egal) wird überschrieben,
    /// statt einen zweiten, nicht unterscheidbaren Chip anzulegen.
    private func savePreset() {
        let name = newPresetName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let preset = PracticePreset(
            id: PracticePresetStore.id(forName: name, in: presets),
            name: name,
            groupIDs: Array(selectedGroupIDs),
            statuses: selectedStatuses.map(\.rawValue),
            topikLevels: selectedTopikLevels.map(\.rawValue),
            problemsOnly: problemsOnly,
            direction: direction.rawValue,
            modes: selectedModes.map(\.rawValue),
            wordLimit: wordLimit
        )
        PracticePresetStore.save(preset)
        presets = PracticePresetStore.all()
    }

    /// Übernimmt ein Preset in den aktuellen Auswahl-Zustand. Gruppen-IDs, die es
    /// nicht mehr gibt, und Modi, die auf diesem Gerät nicht verfügbar sind (z.B.
    /// Hören ohne installierte koreanische Stimme), werden ausgefiltert.
    private func apply(_ preset: PracticePreset) {
        let existing = Set(activeGroups.map(\.id))
        selectedGroupIDs = Set(preset.groupIDs).intersection(existing)
        selectedStatuses = Set(preset.statuses.compactMap(LearningStatus.init(rawValue:)))
        selectedTopikLevels = Set((preset.topikLevels ?? []).compactMap(TopikLevel.init(rawValue:)))
        problemsOnly = preset.problemsOnly ?? false
        direction = PracticeDirection(rawValue: preset.direction) ?? .wordToMeaning
        selectedModes = Set(preset.modes.compactMap(PracticeMode.init(rawValue:)))
            .intersection(PracticeMode.available)
        wordLimit = preset.wordLimit
    }

    private func delete(_ preset: PracticePreset) {
        PracticePresetStore.delete(preset)
        presets = PracticePresetStore.all()
    }
}
