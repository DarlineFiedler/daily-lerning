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
                .opacity(0.9)
            ForEach(achievements) { achievement in
                HStack(spacing: Theme.Spacing.s) {
                    Text(achievement.emoji)
                        .font(.system(size: 30))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(L(achievement.titleKey))
                            .font(.appHeadline)
                        Text(L(achievement.detailKey))
                            .font(.appCaption)
                            .opacity(0.9)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.m)
        .background(Theme.brandGradientSoft, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .shadow(color: Theme.brandStart.opacity(0.35), radius: 14, y: 8)
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
