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
    @State private var meaningLanguage: String?
    @State private var bossMode = false
    @State private var examMode = false
    @State private var startSession = false

    @State private var presets: [PracticePreset] = []
    @State private var showingSavePreset = false
    @State private var newPresetName = ""

    /// Verfügbare Modi werden einmal beim Erscheinen ermittelt (die „Hören"-Prüfung
    /// fragt über AVFoundation nach einer installierten Stimme) – der Startwert lässt
    /// Hören zunächst weg, damit der Render-Pfad frei vom teuren Aufruf bleibt.
    @State private var availableModes: [PracticeMode] = PracticeMode.available(hasVoice: false)

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
                       modes: selectedModes, wordLimit: wordLimit,
                       meaningLanguage: meaningLanguage, bossMode: bossMode,
                       examMode: examMode)
    }

    /// In den ausgewählten Gruppen gepflegte Bedeutungssprachen (für den Sprach-Picker,
    /// Issue #29) – unabhängig vom Status-/TOPIK-Filter, damit der Picker stabil bleibt.
    /// Gecacht statt pro Render berechnet (die Auswertung läuft über alle Vokabeln);
    /// wird beim Erscheinen und bei Gruppenwechsel via `refreshMeaningLanguages` erneuert.
    @State private var availableMeaningLanguages: [String] = []

    /// Erneuert die verfügbaren Sprachen und verwirft eine Auswahl, die es nach einem
    /// Gruppenwechsel nicht mehr gibt (sonst zeigte der Picker eine leere Auswahl).
    private func refreshMeaningLanguages() {
        availableMeaningLanguages =
            Set(resolvedGroups.flatMap(\.vocabs).flatMap(\.availableMeaningLanguages)).sorted()
        if let lang = meaningLanguage, !availableMeaningLanguages.contains(lang) {
            meaningLanguage = nil
        }
    }

    /// Das für die Prüfung maßgebliche TOPIK-Niveau: nur eindeutig, wenn genau ein Level
    /// gewählt ist (steuert Bestehensgrenze und Anzeige im Ergebnis). Bei mehreren/keinem
    /// Level `nil` – der Start-Button verlangt im Prüfungsmodus ohnehin genau ein Level.
    private var examLevel: TopikLevel? {
        selectedTopikLevels.count == 1 ? selectedTopikLevels.first : nil
    }

    /// Im Prüfungsmodus fehlt die Voraussetzung, solange kein TOPIK-Niveau gewählt ist
    /// (die Prüfung ist bewusst level-spezifisch). Steuert Start-Sperre und Hinweis.
    private var examNeedsLevel: Bool { examMode && selectedTopikLevels.isEmpty }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                    Text(L("practice.config.title"))
                        .font(.appTitle)
                        .foregroundStyle(Theme.ink)

                    if !presets.isEmpty { presetSection }
                    if activeGroups.count > 1 { groupSection }
                    statusSection
                    HStack(alignment: .top, spacing: Theme.Spacing.m) {
                        topikSection
                        focusSection
                    }
                    directionSection
                    modesSection
                    if !availableMeaningLanguages.isEmpty { meaningLanguageSection }
                    countSection
                    combatSection
                }
                .padding(Theme.Spacing.m)
            }
            .paperBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("common.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(L("practice.config.savePreset")) {
                        newPresetName = ""
                        showingSavePreset = true
                    }
                    .tint(Theme.vermillion)
                    .disabled(pool.isEmpty)
                }
            }
            .safeAreaInset(edge: .bottom) { startBar }
            .navigationDestination(isPresented: $startSession) {
                if examMode {
                    // Prüfungssimulation: reguläre Engine, aber mit Countdown und
                    // Prüfungs-Auswertung. Zählt normal in SRS/XP/Streak.
                    ExamContainerView(
                        session: PracticeSession(
                            vocabs: pool,
                            distractorPool: resolvedGroups.flatMap(\.vocabs),
                            config: config,
                            context: context
                        ),
                        level: examLevel,
                        onClose: { dismiss() }
                    )
                } else if bossMode {
                    // Endgegner-Modus: eigenständiger, von den Lern-Statistiken getrennter
                    // Kampf-Fluss (Folge zu #89) statt einer regulären Übungsrunde.
                    BossBattleContainerView(
                        session: BossSession(
                            vocabs: pool,
                            distractorPool: resolvedGroups.flatMap(\.vocabs),
                            config: config,
                            context: context
                        ),
                        onClose: { dismiss() }
                    )
                } else {
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
            }
            .onAppear {
                presets = PracticePresetStore.all()
                availableModes = PracticeMode.available
                refreshMeaningLanguages()
            }
            .onChange(of: selectedGroupIDs) { refreshMeaningLanguages() }
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

    /// BEETE – Gruppen-Auswahl. „alle" grün gefüllt, jede Gruppe mit farbigem Punkt.
    private var groupSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            SectionLabel(L("practice.config.groups"))
            FlowChips {
                SelectableChip(
                    title: L("practice.config.allGroups"),
                    tint: Theme.leaf,
                    monospaced: true,
                    isSelected: selectedGroupIDs.isEmpty
                ) { selectedGroupIDs = [] }
                ForEach(activeGroups) { group in
                    SelectableChip(
                        title: group.name,
                        dotColor: Color(hex: group.colorHex),
                        tint: Theme.leaf,
                        monospaced: true,
                        isSelected: selectedGroupIDs.contains(group.id)
                    ) { toggle(&selectedGroupIDs, group.id) }
                }
            }
        }
    }

    /// VORLAGEN – gespeicherte Presets als umrandete Zinnober-Pillen (Tippen wendet an).
    private var presetSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            SectionLabel(L("practice.config.presets"))
            FlowChips {
                ForEach(presets) { preset in
                    SelectableChip(
                        title: preset.name,
                        tint: Theme.vermillion,
                        monospaced: true,
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

    /// WACHSTUM – Lernstatus-Filter mit Wachstumsstufen-Emoji (🌰🌱🌿🌸).
    private var statusSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            SectionLabel(L("practice.config.statuses"))
            FlowChips {
                ForEach(LearningStatus.allCases) { status in
                    SelectableChip(
                        title: L(status.titleKey),
                        leading: status.gardenStageEmoji,
                        tint: status.color,
                        monospaced: true,
                        isSelected: selectedStatuses.contains(status)
                    ) { toggle(&selectedStatuses, status) }
                }
            }
        }
    }

    /// TOPIK – Niveau-Filter (Kurzform I / II), halbe Breite neben dem Fokus.
    private var topikSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            SectionLabel(L("practice.config.topik"))
            FlowChips {
                ForEach(TopikLevel.allCases) { level in
                    SelectableChip(
                        title: level.abbreviation,
                        tint: Theme.leaf,
                        monospaced: true,
                        isSelected: selectedTopikLevels.contains(level)
                    ) { toggle(&selectedTopikLevels, level) }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// FOKUS – nur Problemwörter (Zinnober), halbe Breite neben TOPIK.
    private var focusSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            SectionLabel(L("practice.config.focus"))
            FlowChips {
                SelectableChip(
                    title: L("practice.problems.title"),
                    leading: "⚠",
                    tint: Theme.vermillion,
                    monospaced: true,
                    isSelected: problemsOnly
                ) { problemsOnly.toggle() }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// RICHTUNG – segmentierte Auswahl der Abfragerichtung im Papier-Look.
    private var directionSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            SectionLabel(L("practice.config.direction"))
            PaperSegmented(options: PracticeDirection.allCases,
                           title: { L($0.titleKey) },
                           selection: $direction)
        }
    }

    /// MODI – wählbare Lernmodi als schlichte Pillen (mehrere = Mix, leer = alle).
    private var modesSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            SectionLabel(L("practice.config.modes"))
            FlowChips {
                ForEach(availableModes) { mode in
                    SelectableChip(
                        title: L(mode.titleKey),
                        tint: Theme.leaf,
                        monospaced: true,
                        isSelected: selectedModes.contains(mode)
                    ) { toggle(&selectedModes, mode) }
                }
            }
            Text(L("practice.config.modesHint"))
                .font(.appCaption)
                .foregroundStyle(Theme.inkSecondary)
        }
    }

    /// WIE VIELE – Wortanzahl pro Runde als segmentierte Auswahl (10/20/50/alle).
    private var countSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            SectionLabel(L("practice.config.count"))
            PaperSegmented(options: [10, 20, 50, nil] as [Int?],
                           title: { $0.map(String.init) ?? L("practice.count.all") },
                           selection: $wordLimit)
        }
    }

    /// Bedeutungssprache (Issue #29) – nur wenn im Wortschatz getaggte Sprachen existieren.
    private var meaningLanguageSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            SectionLabel(L("practice.config.meaningLanguage"))
            Picker(L("practice.config.meaningLanguage"), selection: $meaningLanguage) {
                Text(L("practice.config.meaningLanguage.default")).tag(String?.none)
                ForEach(availableMeaningLanguages, id: \.self) { code in
                    Text(DirectionModeSelection.displayName(for: code)).tag(String?.some(code))
                }
            }
            .pickerStyle(.menu)
            .tint(Theme.vermillion)
        }
    }

    /// Endgegner & Prüfung als zwei nebeneinanderliegende Karten – sie schließen sich
    /// gegenseitig aus (Endgegner: eigener Kampf-Fluss; Prüfung: zeitlimitierte TOPIK-Runde).
    private var combatSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            HStack(spacing: Theme.Spacing.s) {
                CombatCard(emoji: "👹", title: L("practice.config.boss"),
                           tint: Theme.vermillion, isSelected: bossMode) {
                    bossMode.toggle()
                    if bossMode { examMode = false } // schließen sich gegenseitig aus
                }
                CombatCard(emoji: "🎓", title: L("practice.exam.card"),
                           tint: Theme.brandMid, isSelected: examMode) {
                    examMode.toggle()
                    if examMode { bossMode = false }
                }
            }
            Text(L("practice.config.combatNote"))
                .font(.appHand(16))
                .foregroundStyle(Theme.inkSecondary)
                .rotationEffect(.degrees(-1.5))
                .padding(.top, 2)
        }
    }

    private var startBar: some View {
        VStack(spacing: 6) {
            Button { startSession = true } label: {
                Text(L("practice.config.start"))
            }
            .buttonStyle(.primary)
            .disabled(pool.isEmpty || examNeedsLevel)

            // Im Prüfungsmodus ohne gewähltes Niveau zuerst dazu auffordern; sonst die
            // (ggf. begrenzte) Wortanzahl von der Trefferzahl zeigen – rot, wenn leer.
            if examNeedsLevel {
                Text(L("practice.exam.needLevel"))
                    .font(.appCaption)
                    .foregroundStyle(Theme.wrong)
            } else {
                Text(L("practice.config.wordCountOfPool", effectiveCount, pool.count))
                    .font(.appCaption)
                    .foregroundStyle(pool.isEmpty ? Theme.wrong : Theme.inkSecondary)
            }
        }
        .padding(Theme.Spacing.m)
        .background(
            Theme.paper.overlay(Rectangle().fill(Theme.hairline).frame(height: 1), alignment: .top)
        )
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

/// Große, tippbare Sonder-Modus-Karte (Endgegner/Prüfung) im Papier-Look: Emoji oben,
/// serifer Titel darunter. Ausgewählt = getönte Fläche mit farbigem 1,5px-Rahmen.
private struct CombatCard: View {
    let emoji: String
    let title: String
    let tint: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(emoji).font(.system(size: 22))
                Text(title)
                    .font(.appHeadline)
                    .foregroundStyle(isSelected ? tint : Theme.inkSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .fill(isSelected ? tint.opacity(0.08) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .strokeBorder(isSelected ? tint : Theme.hairlineStrong,
                                  lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.12), value: isSelected)
        .sensoryFeedback(.selection, trigger: isSelected)
    }
}
