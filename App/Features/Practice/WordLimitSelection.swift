import SwiftUI

/// Wiederverwendbare Auswahl der Wortanzahl pro Durchgang (`wordLimit`). Wird sowohl
/// im vollständigen Übungs-Konfig-Screen (`PracticeConfigView`) als auch vor dem
/// „Heute"-Lernvorgang (`ReviewSessionView`) genutzt, damit beide Stellen dieselbe
/// UI und Semantik teilen. `nil` = alle Wörter des Pools.
struct WordLimitSelection: View {
    @Binding var wordLimit: Int?

    /// Wählbare Session-Längen (nil = alle).
    private let limitOptions: [Int?] = [10, 20, 50, nil]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            SectionHeader(L("practice.config.count"))
            FlowChips {
                ForEach(limitOptions, id: \.self) { option in
                    SelectableChip(
                        title: option.map(String.init) ?? L("practice.count.all"),
                        systemImage: "number",
                        tint: Theme.brandStart,
                        isSelected: wordLimit == option
                    ) { wordLimit = option }
                }
            }
        }
    }
}
