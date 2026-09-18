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
                .foregroundStyle(Theme.ocher)
                .scaleEffect(appeared ? 1 : 0.4)
                .rotationEffect(.degrees(appeared ? 0 : -20))
            VStack(alignment: .leading, spacing: 2) {
                Text(L("xp.levelUp.title", level.level))
                    .font(.appHeadline)
                    .foregroundStyle(Theme.ink)
                Text(L(level.rankKey))
                    .font(.appTitle3)
                    .foregroundStyle(Theme.vermillion)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.m)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .strokeBorder(Theme.ocher.opacity(0.5), lineWidth: 1.5)
        )
        .hardShadow(x: 3, y: 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(L("xp.levelUp.a11y", level.level, L(level.rankKey)))
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { appeared = true }
        }
    }
}
