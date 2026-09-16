import SwiftUI

/// Runder, tippbarer Auswahl-Chip (Icon + Text). Ersetzt die Häkchen-Zeilen
/// (`multiToggle`) bei der Lern-Konfiguration. Ausgewählt = getönter Verlauf.
struct SelectableChip: View {
    let title: String
    var systemImage: String?
    /// Optionales Emoji vor dem Titel (z.B. Wachstumsstufe 🌱 oder ⚠). Hat Vorrang
    /// vor `systemImage`, damit die Papier-Chips ohne SF-Symbole auskommen.
    var leading: String?
    /// Optionaler farbiger Punkt vor dem Titel (Beet-/Gruppenfarbe im Design-Handoff 2a).
    var dotColor: Color?
    var tint: Color = Theme.brandStart
    /// Monospace-Beschriftung (Courier Prime) statt Serife – für die Papier-Pillen der
    /// Runden-Konfiguration (Design-Handoff 2a). Standard bleibt die serife App-Schrift.
    var monospaced: Bool = false
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let dotColor {
                    Text("●")
                        .font(.system(size: 9))
                        .foregroundStyle(isSelected ? .white : dotColor)
                }
                if let leading {
                    Text(leading)
                } else if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
            .font(monospaced ? .appMono(12) : .appSubheadline.weight(.medium))
            .foregroundStyle(isSelected ? .white : Color.primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background {
                if isSelected {
                    Capsule().fill(tint.vibrantGradient)
                } else {
                    Capsule().fill(Theme.surfaceMuted)
                }
            }
            .overlay {
                if !isSelected {
                    Capsule().strokeBorder(tint.opacity(0.25), lineWidth: 1)
                }
            }
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        .sensoryFeedback(.selection, trigger: isSelected)
    }
}
