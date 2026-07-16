import SwiftUI

/// Weiche, abgerundete Karten-Fläche mit Schatten – ersetzt die grauen
/// `Color.gray.opacity(0.12)`-Boxen der ursprünglichen Optik.
struct CardBackground: ViewModifier {
    var padding: CGFloat = Theme.Spacing.m
    var radius: CGFloat = Theme.Radius.card

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .shadow(color: Theme.Shadow.color, radius: Theme.Shadow.radius, y: Theme.Shadow.y)
    }
}

extension View {
    /// Verpackt den Inhalt in eine helle Karte mit Rundung und Schatten.
    func cardStyle(padding: CGFloat = Theme.Spacing.m, radius: CGFloat = Theme.Radius.card) -> some View {
        modifier(CardBackground(padding: padding, radius: radius))
    }
}

/// Karte mit farbigem Verlauf als Hintergrund (für Gruppen/Header). Der Inhalt
/// wird in Weiß gezeichnet und bleibt so auf den kräftigen Farben lesbar.
struct GradientCard<Content: View>: View {
    let gradient: LinearGradient
    var radius: CGFloat = Theme.Radius.card
    var padding: CGFloat = Theme.Spacing.m
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(gradient, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .foregroundStyle(.white)
            .shadow(color: Theme.Shadow.color, radius: Theme.Shadow.radius, y: Theme.Shadow.y)
    }
}
