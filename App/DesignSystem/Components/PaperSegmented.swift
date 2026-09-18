import SwiftUI

/// Segmentierte Auswahl im Papier-Look: gleich breite, einzeln umrandete Kästchen
/// (4pt-Radius) mit kleinem Abstand. Das aktive Segment ist satt gefüllt (Standard
/// Blattgrün) mit Papiertext, die übrigen tragen nur einen Haarlinien-Rahmen.
/// Ersetzt `Picker(.segmented)` dort, wo der Print-Look gefragt ist
/// (Design-Handoff 2a: „Richtung", „Wie viele").
struct PaperSegmented<Option: Hashable>: View {
    let options: [Option]
    let title: (Option) -> String
    @Binding var selection: Option
    var selectedFill: Color = Theme.leaf

    var body: some View {
        HStack(spacing: 6) {
            ForEach(options, id: \.self) { option in
                let isSelected = option == selection
                Button { selection = option } label: {
                    Text(title(option))
                        .font(.appMono(12))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(isSelected ? Color(hex: "#FBF5EA") : Theme.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous)
                                .fill(isSelected ? selectedFill : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous)
                                .strokeBorder(isSelected ? Color.clear : Theme.hairlineStrong, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .animation(.easeOut(duration: 0.12), value: selection)
        .sensoryFeedback(.selection, trigger: selection)
    }
}
