import SwiftUI

/// Reihe gleich breiter [[StatTile]]s. Bei Accessibility-Textgrößen stapelt sie
/// vertikal (volle Breite je Kachel) statt die Kacheln horizontal zu quetschen,
/// wo große Zahlen/Labels sonst abschneiden würden (Issue #120).
struct StatTileRow<Content: View>: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    @ViewBuilder var content: () -> Content

    var body: some View {
        if StatTileRow.isStacked(typeSize) {
            VStack(spacing: Theme.Spacing.s) { content() }
        } else {
            HStack(spacing: Theme.Spacing.s) { content() }
        }
    }

    /// Testbare Layout-Entscheidung: ab Accessibility-Größen vertikal stapeln.
    static func isStacked(_ size: DynamicTypeSize) -> Bool { size.isAccessibilitySize }
}
