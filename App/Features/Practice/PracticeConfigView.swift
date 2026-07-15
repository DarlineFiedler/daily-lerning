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
            Form {
                Section {
                    ForEach(LearningStatus.allCases) { status in
                        multiToggle(
                            title: L(status.titleKey),
                            systemImage: status.systemImage,
                            tint: status.color,
                            isOn: selectedStatuses.contains(status)
                        ) { toggleStatus(status) }
                    }
                } header: {
                    Text(L("practice.config.statuses"))
                } footer: {
                    Text(L("common.all")).opacity(selectedStatuses.isEmpty ? 1 : 0.4)
                }

                Section(L("practice.config.direction")) {
                    Picker(L("practice.config.direction"), selection: $direction) {
                        ForEach(PracticeDirection.allCases) { dir in
                            Text(L(dir.titleKey)).tag(dir)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                Section {
                    ForEach(PracticeMode.allCases) { mode in
                        multiToggle(
                            title: L(mode.titleKey),
                            systemImage: mode.systemImage,
                            tint: .accentColor,
                            isOn: selectedModes.contains(mode)
                        ) { toggleMode(mode) }
                    }
                } header: {
                    Text(L("practice.config.modes"))
                } footer: {
                    Text(L("practice.config.modesHint"))
                }
            }
            .navigationTitle(L("practice.config.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("common.cancel")) { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 4) {
                    Button {
                        startSession = true
                    } label: {
                        Label(L("common.start"), systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(pool.isEmpty)

                    Text(L("group.wordCount", pool.count))
                        .font(.caption)
                        .foregroundStyle(pool.isEmpty ? .red : .secondary)
                }
                .padding()
                .background(.bar)
            }
            .navigationDestination(isPresented: $startSession) {
                PracticeContainerView(
                    session: PracticeSession(
                        vocabs: pool,
                        distractorPool: group.vocabs,
                        config: config,
                        context: context
                    )
                )
            }
        }
    }

    @ViewBuilder
    private func multiToggle(
        title: String,
        systemImage: String,
        tint: Color,
        isOn: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                Label(title, systemImage: systemImage)
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isOn ? tint : Color.secondary.opacity(0.4))
            }
        }
    }

    private func toggleStatus(_ status: LearningStatus) {
        if selectedStatuses.contains(status) { selectedStatuses.remove(status) }
        else { selectedStatuses.insert(status) }
    }

    private func toggleMode(_ mode: PracticeMode) {
        if selectedModes.contains(mode) { selectedModes.remove(mode) }
        else { selectedModes.insert(mode) }
    }
}
