import SwiftUI

/// Wiederverwendbare Auswahl von Abfragerichtung (`PracticeDirection`) und Lernmodi
/// (`PracticeMode`). Wird sowohl im vollständigen Übungs-Konfig-Screen
/// (`PracticeConfigView`) als auch vor dem „Heute"-Lernvorgang (`ReviewSessionView`)
/// genutzt, damit beide Stellen dieselbe UI und Semantik teilen.
struct DirectionModeSelection: View {
    @Binding var direction: PracticeDirection
    @Binding var modes: Set<PracticeMode>
    /// Gewählte Bedeutungssprache (Sprachcode) oder `nil` für die Standard-/Primär-
    /// bedeutung (Issue #29). Nur relevant, wenn `availableMeaningLanguages` nicht leer ist.
    @Binding var meaningLanguage: String?
    /// Im Wortschatz tatsächlich gepflegte Bedeutungssprachen (Sprachcodes). Ist die Liste
    /// leer, wird der Sprach-Picker ausgeblendet – dann verhält sich die View wie zuvor.
    var availableMeaningLanguages: [String] = []

    init(direction: Binding<PracticeDirection>,
         modes: Binding<Set<PracticeMode>>,
         meaningLanguage: Binding<String?> = .constant(nil),
         availableMeaningLanguages: [String] = []) {
        _direction = direction
        _modes = modes
        _meaningLanguage = meaningLanguage
        self.availableMeaningLanguages = availableMeaningLanguages
    }

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
            if !availableMeaningLanguages.isEmpty { meaningLanguageSection }
            modeSection
        }
        .onAppear { availableModes = PracticeMode.available }
    }

    /// Sprach-Picker für die Bedeutung. Nur sichtbar, wenn im Wortschatz überhaupt
    /// getaggte Bedeutungssprachen existieren. „Standard" (nil) nutzt die Primär-
    /// bedeutung; fehlt die gewählte Sprache an einer Vokabel, greift der Fallback.
    private var meaningLanguageSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            SectionHeader(L("practice.config.meaningLanguage"))
            Picker(L("practice.config.meaningLanguage"), selection: $meaningLanguage) {
                Text(L("practice.config.meaningLanguage.default")).tag(String?.none)
                ForEach(availableMeaningLanguages, id: \.self) { code in
                    Text(Self.displayName(for: code)).tag(String?.some(code))
                }
            }
            .pickerStyle(.menu)
        }
    }

    /// Menschlich lesbarer Sprachname zu einem Code (z.B. „en" → „Englisch"), sonst der
    /// Code in Großbuchstaben als Rückfall.
    static func displayName(for code: String) -> String {
        Locale.current.localizedString(forLanguageCode: code) ?? code.uppercased()
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
