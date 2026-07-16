import SwiftUI

/// Gefüllter Marken-Gradient-Button mit Press-Animation und Haptik.
/// Ersetzt `.buttonStyle(.borderedProminent)` für alle Haupt-Aktionen.
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.appHeadline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background {
                RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous)
                    .fill(Theme.brandGradient)
            }
            .opacity(isEnabled ? 1 : 0.4)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .shadow(color: Theme.brandEnd.opacity(isEnabled ? 0.35 : 0),
                    radius: 12, y: 6)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
            .sensoryFeedbackOnPress(configuration.isPressed)
    }
}

/// Getönter, umrandeter Sekundär-Button (gleiche Form, dezenter).
struct SecondaryButtonStyle: ButtonStyle {
    var tint: Color = Theme.brandStart

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.appHeadline)
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background {
                RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous)
                    .fill(tint.opacity(0.14))
            }
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
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
