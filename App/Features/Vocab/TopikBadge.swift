import SwiftUI

/// Kompaktes Niveau-Abzeichen („TOPIK I" / „TOPIK II") für Listen und Detailansichten.
/// Zeigt nichts an, wenn die Vokabel nicht eingestuft ist (`level == nil`).
struct TopikBadge: View {
    let level: TopikLevel?

    var body: some View {
        if let level {
            Text("TOPIK \(level.abbreviation)")
                .font(.appCaption)
                .fontWeight(.semibold)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.accentColor.opacity(0.15), in: Capsule())
                .foregroundStyle(Color.accentColor)
                .accessibilityLabel(L(level.titleKey))
        }
    }
}
