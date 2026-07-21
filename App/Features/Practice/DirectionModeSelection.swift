import SwiftUI

/// Wiederverwendbare Auswahl von Abfragerichtung (`PracticeDirection`) und Lernmodi
/// (`PracticeMode`). Wird sowohl im vollständigen Übungs-Konfig-Screen
/// (`PracticeConfigView`) als auch vor dem „Heute"-Lernvorgang (`ReviewSessionView`)
/// genutzt, damit beide Stellen dieselbe UI und Semantik teilen.
struct DirectionModeSelection: View {
    @Binding var direction: PracticeDirection
    @Binding var modes: Set<PracticeMode>

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            directionSection
            modeSection
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
                ForEach(PracticeMode.available) { mode in
                    SelectableChip(
                        title: L(mode.titleKey),
                        systemImage: mode.systemImage,
                        tint: Theme.brandStart,
                        isSelected: modes.contains(mode)
                    ) { toggle(mode) }
                }
            }
            Text(L("practice.config.modesHint"))
                .font(.appCaption)
                .foregroundStyle(.secondary)
        }
    }

    private func toggle(_ mode: PracticeMode) {
        if modes.contains(mode) { modes.remove(mode) } else { modes.insert(mode) }
    }
}
