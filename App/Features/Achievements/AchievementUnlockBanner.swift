import SwiftUI

/// Kurzes Freischalt-Feedback: schiebt sich von oben ein, wenn in einer Runde neue
/// Badges erreicht wurden, und blendet sich nach ein paar Sekunden wieder aus.
/// Mehrere gleichzeitig freigeschaltete Badges werden gestapelt gezeigt.
struct AchievementUnlockBanner: View {
    let achievements: [Achievement]

    @State private var shown = false
    @State private var hideTask: Task<Void, Never>?

    var body: some View {
        Group {
            if !achievements.isEmpty, shown {
                banner
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: shown)
        .onChange(of: achievements.map(\.id)) { _, ids in
            if !ids.isEmpty { reveal() }
        }
        .onAppear { if !achievements.isEmpty { reveal() } }
    }

    private var banner: some View {
        VStack(spacing: Theme.Spacing.xs) {
            Text(L("ach.new.title"))
                .font(.appCaption.weight(.bold))
                .textCase(.uppercase)
                .foregroundStyle(Theme.leaf)
            ForEach(achievements) { achievement in
                HStack(spacing: Theme.Spacing.s) {
                    Text(achievement.emoji)
                        .font(.system(size: 30))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(L(achievement.titleKey))
                            .font(.appHeadline)
                            .foregroundStyle(Theme.ink)
                        Text(L(achievement.detailKey))
                            .font(.appCaption)
                            .foregroundStyle(Theme.inkSecondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
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
        .padding(.horizontal, Theme.Spacing.m)
        .padding(.top, Theme.Spacing.s)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isStaticText)
    }

    /// Einblenden und nach kurzer Zeit automatisch wieder ausblenden. Ein evtl.
    /// noch laufender Ausblend-Timer wird verworfen, damit eine neue Badge-Charge
    /// nicht vom Timer der vorigen vorzeitig ausgeblendet wird.
    private func reveal() {
        shown = true
        hideTask?.cancel()
        hideTask = Task {
            try? await Task.sleep(for: .seconds(3.5))
            guard !Task.isCancelled else { return }
            shown = false
        }
    }
}
