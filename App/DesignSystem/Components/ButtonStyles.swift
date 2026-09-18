import SwiftUI

/// Gefüllter Primär-Button im Papier-Look: satte Füllfarbe (Standard Zinnober),
/// Serifen-Schrift auf hellem Papierton und ein **harter Schatten in der dunklen
/// Variante der Füllfarbe** (`0 4px 0`). Beim Drücken „sinkt" der Button ins Papier
/// (kein Bounce, kurzer ease-out). Ersetzt `.borderedProminent` für Haupt-Aktionen.
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    var fill: Color = Theme.vermillion
    var shadowColor: Color = Theme.vermillionDark

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        return configuration.label
            .font(.appHeadline)
            .foregroundStyle(Color(hex: "#FBF5EA"))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background {
                RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous)
                    .fill(fill)
            }
            .opacity(isEnabled ? 1 : 0.4)
            .offset(y: pressed ? 3 : 0)
            .buttonHardShadow(isEnabled ? shadowColor : .clear, y: pressed ? 1 : 4)
            .animation(.easeOut(duration: 0.12), value: pressed)
            .sensoryFeedbackOnPress(pressed)
    }
}

/// Getönter, umrandeter Sekundär-Button (gleiche Form, dezenter): Tönung der Tintfarbe
/// als Fläche, 1px Rahmen, kein harter Schatten.
struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    var tint: Color = Theme.ink

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.appHeadline)
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background {
                RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous)
                    .fill(tint.opacity(0.10))
            }
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous)
                    .strokeBorder(tint.opacity(0.20), lineWidth: 1)
            )
            .opacity(isEnabled ? 1 : 0.4)
            .offset(y: configuration.isPressed ? 2 : 0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    /// Zinnober-Primär-Button („Üben").
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
    /// Primär-Button in beliebiger Füllfarbe (z.B. Blattgrün „Weiter", Tinte „Verstanden").
    static func primary(fill: Color, shadow: Color) -> PrimaryButtonStyle {
        PrimaryButtonStyle(fill: fill, shadowColor: shadow)
    }
    /// „Weiter"-Button (richtig): Blattgrün.
    static var forward: PrimaryButtonStyle { PrimaryButtonStyle(fill: Theme.leaf, shadowColor: Theme.leafDark) }
    /// „Verstanden"-Button (falsch): Tinte.
    static var acknowledge: PrimaryButtonStyle { PrimaryButtonStyle(fill: Theme.ink, shadowColor: .black) }
}

extension ButtonStyle where Self == SecondaryButtonStyle {
    static var secondary: SecondaryButtonStyle { SecondaryButtonStyle() }
    static func secondary(tint: Color) -> SecondaryButtonStyle { SecondaryButtonStyle(tint: tint) }
}

private extension View {
    /// Löst beim Drücken eine leichte Haptik aus (iOS 17+).
    @ViewBuilder
    func sensoryFeedbackOnPress(_ pressed: Bool) -> some View {
        self.sensoryFeedback(.impact(weight: .light), trigger: pressed) { _, now in now }
    }
}
