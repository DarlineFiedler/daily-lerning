import SwiftUI

/// Führt durch einen eigenständigen Endgegner-Kampf (Folge zu #89): Boss-Kopfzeile
/// (HP-Leiste + Leben), die passende Modus-Karte pro Wort, ein Aufgeben-Button und am
/// Ende der Sieg-/Niederlage-Screen. Reine Präsentation über `BossSession`; die
/// Kampf-Logik (und die Statistik-Neutralität) steckt in der Session.
struct BossBattleContainerView: View {
    @State var session: BossSession
    /// Beendet den Kampf (schließt das Sheet/den Navigations-Fluss).
    var onClose: () -> Void

    @State private var showGiveUpConfirm = false

    var body: some View {
        VStack(spacing: 0) {
            if session.totalWords == 0 {
                emptyState
            } else if let outcome = session.outcome {
                BossResultView(session: session, outcome: outcome,
                               onRestart: { withAnimation { session.restart() } },
                               onClose: onClose)
            } else if let item = session.currentItem {
                BossBattleHeader(battle: session.battle,
                                 bossGroup: session.bossGroup,
                                 hitTrigger: session.correctCount)
                ScrollView {
                    card(for: item)
                        .padding(Theme.Spacing.m)
                        .id(session.turns) // erzwingt frische State pro Karte
                }
                // Gegenschlag des Bosses: Screen-Shake bei jeder falschen Antwort.
                .modifier(ShakeEffect(animatableData: CGFloat(session.wrongCount)))
                .animation(.linear(duration: 0.4), value: session.wrongCount)
                giveUpBar
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(L("common.close"), action: onClose)
            }
        }
        .sensoryFeedback(.success, trigger: session.correctCount)
        .sensoryFeedback(.error, trigger: session.wrongCount)
        .overlay(alignment: .top) {
            AchievementUnlockBanner(achievements: session.newlyUnlocked)
        }
    }

    @ViewBuilder
    private func card(for item: PracticeItem) -> some View {
        let onAnswer: (Bool) -> Void = { correct in
            withAnimation { session.answer(correct: correct) }
        }
        switch item.mode {
        case .multipleChoice:
            MultipleChoiceView(item: item, onAnswer: onAnswer)
        case .review:
            ReviewSwipeView(item: item, onAnswer: onAnswer)
        case .writing:
            WritingView(item: item, onAnswer: onAnswer)
        case .listening:
            ListeningView(item: item, onAnswer: onAnswer)
        case .cloze:
            ClozeView(item: item, onAnswer: onAnswer)
        }
    }

    private var giveUpBar: some View {
        Button(role: .destructive) { showGiveUpConfirm = true } label: {
            Label(L("practice.boss.giveUp"), systemImage: "flag.fill")
                .font(.appSubheadline.weight(.medium))
        }
        .tint(Theme.wrong)
        .padding(.vertical, Theme.Spacing.s)
        .confirmationDialog(L("practice.boss.giveUp.confirm"), isPresented: $showGiveUpConfirm, titleVisibility: .visible) {
            Button(L("practice.boss.giveUp"), role: .destructive) { withAnimation { session.giveUp() } }
            Button(L("common.cancel"), role: .cancel) {}
        }
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.m) {
            Image(systemName: "square.dashed")
                .font(.system(size: 52))
                .foregroundStyle(Theme.brandStart)
            Text(L("practice.noWords"))
                .font(.appBody)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button(L("common.done"), action: onClose)
                .buttonStyle(.primary)
                .padding(.horizontal, Theme.Spacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Theme.Spacing.l)
    }
}

// MARK: - Kampf-Bausteine

/// Ausgang eines Endgegner-Kampfes für den Ergebnis-Screen.
enum BossOutcome: Equatable {
    case victory
    case defeat

    var emoji: String {
        switch self {
        case .victory: return "🏆"
        case .defeat: return "💀"
        }
    }

    var titleKey: String {
        switch self {
        case .victory: return "practice.boss.victory"
        case .defeat: return "practice.boss.defeat"
        }
    }
}

/// Horizontaler „Screen-Shake" – der Gegenschlag des Bosses bei einer falschen
/// Antwort. `animatableData` ist die (falsche) Antwortzahl; jeder Sprung um 1
/// erzeugt genau einen Wackel-Zyklus.
struct ShakeEffect: GeometryEffect {
    var animatableData: CGFloat

    func effectValue(size _: CGSize) -> ProjectionTransform {
        let dx = 8 * sin(animatableData * .pi * 6)
        return ProjectionTransform(CGAffineTransform(translationX: dx, y: 0))
    }
}

/// Kampf-Kopfzeile: Boss (Name der einzigen Gruppe oder generisch) mit HP-Leiste plus
/// Herz-Anzeige der verbleibenden Leben. Rein visuell – die Werte kommen als `battle`.
struct BossBattleHeader: View {
    let battle: BossBattle
    let bossGroup: VocabGroup?
    /// Auslöser der Treffer-Animation (die steigende Trefferzahl).
    let hitTrigger: Int

    /// Ab dieser Lebenszahl wird kompakt „❤️ ×N" statt einzelner Herzen gezeigt.
    private static let heartsThreshold = 6

    private var tint: Color {
        bossGroup.map { Color(hex: $0.colorHex) } ?? Theme.brandStart
    }

    private var bossName: String {
        bossGroup?.name ?? L("practice.boss.generic")
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.s) {
            HStack(spacing: Theme.Spacing.s) {
                Text("🐲")
                    .font(.system(size: 34))
                    .phaseAnimator([1.0, 0.82, 1.0], trigger: hitTrigger) { view, scale in
                        view.scaleEffect(scale)
                    }
                VStack(alignment: .leading, spacing: 2) {
                    Text(bossName)
                        .font(.appHeadline)
                        .lineLimit(1)
                    Text(L("practice.boss.hp", battle.currentHP, battle.maxHP))
                        .font(.appCaption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                lives
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.surfaceMuted)
                    Capsule().fill(tint)
                        .frame(width: geo.size.width * battle.hpFraction)
                        .animation(.easeOut(duration: 0.3), value: battle.currentHP)
                }
            }
            .frame(height: 10)
        }
        .padding(.horizontal, Theme.Spacing.m)
        .padding(.top, Theme.Spacing.s)
        // Kampf-Status als ein VoiceOver-Element (statt loser Emoji/Balken/Herzen).
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L("practice.boss.a11y.status", bossName,
                               battle.currentHP, battle.maxHP, battle.livesRemaining))
    }

    /// Verbleibende Leben – einzelne Herzen bei kleinen Runden, sonst kompakt.
    @ViewBuilder
    private var lives: some View {
        if battle.maxLives > Self.heartsThreshold {
            Label("\(battle.livesRemaining)", systemImage: "heart.fill")
                .font(.appCaption.weight(.semibold))
                .foregroundStyle(Theme.wrong)
        } else {
            HStack(spacing: 2) {
                ForEach(0 ..< battle.maxLives, id: \.self) { i in
                    Image(systemName: i < battle.livesRemaining ? "heart.fill" : "heart")
                        .font(.appCaption)
                        .foregroundStyle(Theme.wrong)
                }
            }
        }
    }
}

/// Ergebnis-Screen des Kampfes: Sieg-/Niederlage-Hero plus Kampf-Kennzahlen (Treffer,
/// Durchgänge, Fehler) und Aktionen (nochmal / schließen).
struct BossResultView: View {
    let session: BossSession
    let outcome: BossOutcome
    var onRestart: () -> Void
    var onClose: () -> Void

    @State private var appeared = false

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.l) {
                Text(outcome.emoji)
                    .font(.system(size: 72))
                    .scaleEffect(appeared ? 1 : 0.4)
                    .rotationEffect(.degrees(appeared ? 0 : -20))
                Text(L(outcome.titleKey))
                    .font(.appLargeTitle)
                    .multilineTextAlignment(.center)

                HStack(spacing: Theme.Spacing.s) {
                    StatTile(value: "\(session.correctCount)", label: L("practice.boss.stat.hits"),
                             systemImage: "burst.fill", tint: Theme.brandStart)
                    StatTile(value: "\(session.round)", label: L("practice.boss.stat.rounds"),
                             systemImage: "arrow.triangle.2.circlepath", tint: Theme.brandEnd)
                    StatTile(value: "\(session.wrongCount)", label: L("practice.boss.stat.misses"),
                             systemImage: "heart.slash.fill", tint: Theme.wrong)
                }

                VStack(spacing: Theme.Spacing.s) {
                    Button(action: onRestart) {
                        Label(L("practice.restart"), systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.primary)
                    Button(action: onClose) {
                        Text(L("common.done"))
                    }
                    .buttonStyle(.secondary)
                }
            }
            .padding(Theme.Spacing.l)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { appeared = true }
        }
    }
}
