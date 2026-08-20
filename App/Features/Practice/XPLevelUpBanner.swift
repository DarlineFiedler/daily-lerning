import SwiftUI

/// Feiert einen Levelaufstieg am Rundenende: eine hervorgehobene Karte im Stil des
/// [[AchievementUnlockBanner]] (Marken-Verlauf, Stern-Symbol), die das neu erreichte
/// Level und den zugehörigen Rangnamen zeigt.
struct XPLevelUpBanner: View {
    let level: XPLevel

    @State private var appeared = false

    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            Image(systemName: "star.circle.fill")
                .font(.system(size: 36))
                .scaleEffect(appeared ? 1 : 0.4)
                .rotationEffect(.degrees(appeared ? 0 : -20))
            VStack(alignment: .leading, spacing: 2) {
                Text(L("xp.levelUp.title", level.level))
                    .font(.appHeadline)
                Text(L(level.rankKey))
                    .font(.appTitle3)
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.m)
        .background(Theme.brandGradientSoft, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .shadow(color: Theme.brandStart.opacity(0.35), radius: 14, y: 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(L("xp.levelUp.a11y", level.level, L(level.rankKey)))
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { appeared = true }
        }
    }
}
