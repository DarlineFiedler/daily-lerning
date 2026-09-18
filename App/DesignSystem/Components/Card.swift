import SwiftUI

/// Papierkarte mit Haarlinien-Rahmen und hartem Offset-Schatten (Print-Look).
struct CardBackground: ViewModifier {
    var padding: CGFloat = Theme.Spacing.m
    var radius: CGFloat = Theme.Radius.card

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Theme.hairline, lineWidth: 1)
            )
            .hardShadow()
    }
}

extension View {
    /// Verpackt den Inhalt in eine helle Karte mit Rundung und Schatten.
    func cardStyle(padding: CGFloat = Theme.Spacing.m, radius: CGFloat = Theme.Radius.card) -> some View {
        modifier(CardBackground(padding: padding, radius: radius))
    }
}

/// Großflächige „Held"-Karte im weichen Marken-Verlauf: zentrierter Inhalt in Weiß,
/// kräftiger Marken-Schatten. Geteilte Optik der Übungskarte (`ReviewSwipeView`) und der
/// Wort-Detailansicht (`VocabDetailView`) – dort NICHT dupliziert, sondern hierüber.
struct HeroCardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.xl + 16)
            .padding(.horizontal, Theme.Spacing.m)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .strokeBorder(Theme.hairline, lineWidth: 1)
            )
            .foregroundStyle(Theme.ink)
            .hardShadow(x: 3, y: 4)
    }
}

extension View {
    /// Verpackt den Inhalt in die große Marken-Kopfkarte (Übungs-/Detailansicht).
    func heroCardStyle() -> some View { modifier(HeroCardBackground()) }
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
            .hardShadow()
    }
}
