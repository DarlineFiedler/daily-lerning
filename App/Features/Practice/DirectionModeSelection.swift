import SwiftUI

/// Wiederverwendbare Auswahl von Abfragerichtung (`PracticeDirection`) und Lernmodi
/// (`PracticeMode`). Wird sowohl im vollständigen Übungs-Konfig-Screen
/// (`PracticeConfigView`) als auch vor dem „Heute"-Lernvorgang (`ReviewSessionView`)
/// genutzt, damit beide Stellen dieselbe UI und Semantik teilen.
struct DirectionModeSelection: View {
    @Binding var direction: PracticeDirection
    @Binding var modes: Set<PracticeMode>

    /// Verfügbare Modi werden einmal beim Erscheinen ermittelt statt bei jedem
    /// Render (z.B. jedem Chip-Tap): die Verfügbarkeitsprüfung fragt über
    /// AVFoundation nach einer installierten Stimme. Der Startwert lässt Hören
    /// zunächst weg (reiner Array-Filter, kein AVFoundation-Aufruf) und wird in
    /// `onAppear` durch das echte Ergebnis ersetzt – so bleibt der Render-Pfad frei
    /// vom teuren Aufruf, und eine zwischenzeitlich installierte Stimme wird beim
    /// erneuten Öffnen berücksichtigt.
    @State private var availableModes: [PracticeMode] = PracticeMode.available(hasVoice: false)

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            directionSection
            modeSection
        }
        .onAppear { availableModes = PracticeMode.available }
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
                ForEach(availableModes) { mode in
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
