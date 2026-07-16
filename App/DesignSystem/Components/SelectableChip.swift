import SwiftUI

/// Runder, tippbarer Auswahl-Chip (Icon + Text). Ersetzt die Häkchen-Zeilen
/// (`multiToggle`) bei der Lern-Konfiguration. Ausgewählt = getönter Verlauf.
struct SelectableChip: View {
    let title: String
    var systemImage: String?
    var tint: Color = Theme.brandStart
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
            .font(.appSubheadline.weight(.medium))
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
