import SwiftUI

/// Freischalt-Feedback im Ergebnis-Screen (Übung, Prüfung, Boss-Kampf): eine eigene
/// Sektion mit allen in dieser Runde neu erreichten Badges, gestapelt. Bewusst kein
/// Overlay mehr – das hatte am Rundenende Emoji und Überschrift des Ergebnisses
/// verdeckt (Issue #174). Bei leerer Liste wird nichts gerendert.
struct AchievementUnlockCard: View {
    let achievements: [Achievement]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    /// Emoji wächst mit Dynamic Type mit, damit es neben dem Titel nicht verkümmert.
    @ScaledMetric(relativeTo: .title) private var emojiSize: CGFloat = 30

    var body: some View {
        if !achievements.isEmpty {
            card
                .onAppear {
                    withAnimation(Motion.animation(.spring(response: 0.5, dampingFraction: 0.6),
                                                   reduceMotion: reduceMotion)) { appeared = true }
                }
        }
    }

    private var card: some View {
        VStack(spacing: Theme.Spacing.xs) {
            Text(L("ach.new.title"))
                .font(.appCaption.weight(.bold))
                .textCase(.uppercase)
                .foregroundStyle(Theme.leaf)
            ForEach(achievements) { achievement in
                HStack(spacing: Theme.Spacing.s) {
                    Text(achievement.emoji)
                        .font(.system(size: emojiSize))
                        .scaleEffect(appeared ? 1 : 0.4)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(L(achievement.titleKey))
                            .font(.appHeadline)
                            .foregroundStyle(Theme.ink)
                        Text(L(achievement.detailKey))
                            .font(.appCaption)
                            .foregroundStyle(Theme.inkSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                // Je Badge ein VoiceOver-Element, statt die ganze Karte als einen Block vorzulesen.
                .accessibilityElement(children: .combine)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.m)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .strokeBorder(Theme.leaf.opacity(0.5), lineWidth: 1.5)
        )
        .hardShadow(x: 3, y: 4)
        .accessibilityElement(children: .contain)
    }
}
