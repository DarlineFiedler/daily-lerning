import SwiftUI

/// Führt durch einen Lernvorgang und zeigt je Wort die passende Modus-View.
struct PracticeContainerView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State var session: PracticeSession
    /// Beendet den gesamten Lernvorgang (schließt das Practice-Sheet).
    var onClose: () -> Void
    /// App-weiter Session-Speicher für die Live Activity (optional – Previews/Tests
    /// laufen ohne). Wird von den Aufruf-Stellen aus dem Environment durchgereicht.
    var sessionStore: ActiveSessionStore?
    /// Ob diese Session aus der Live Activity heraus wieder-präsentierbar ist
    /// (nur der „Heute"-Fluss).
    var resumable = false

    var body: some View {
        VStack(spacing: 0) {
            if session.total == 0 {
                // Nur-Lückentext-Runde, in der kein Wort einen Beispielsatz hat.
                emptyState
            } else if session.currentItem == nil {
                PracticeSummaryView(
                    session: session,
                    bossOutcome: bossOutcome,
                    onRestart: { withAnimation { session.restart() } },
                    onRetryWrong: { withAnimation { session.retryWrong() } },
                    onClose: handleClose
                )
            } else if let item = session.currentItem {
                if session.isBossMode {
                    BossBattleHeader(session: session)
                } else {
                    PracticeProgressHeader(session: session)
                }
                ScrollView {
                    modeView(for: item)
                        .padding(Theme.Spacing.m)
                        .id(session.index) // erzwingt frische State pro Wort
                }
                // Endgegner-Modus: Gegenschlag = Screen-Shake bei jeder falschen Antwort.
                .modifier(ShakeEffect(animatableData: session.isBossMode ? CGFloat(session.wrongCount) : 0))
                .animation(.linear(duration: 0.4), value: session.wrongCount)
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(L("common.close"), action: handleClose)
            }
        }
        // Haptik für die wichtigsten Lern-Momente (richtig/falsch).
        .sensoryFeedback(.success, trigger: session.correctCount)
        .sensoryFeedback(.error, trigger: session.wrongCount)
        .overlay(alignment: .top) {
            AchievementUnlockBanner(achievements: session.newlyUnlocked)
        }
        // Live Activity: bei Sessionbeginn starten, pro Karte aktualisieren, bei
        // Abschluss/Schließen beenden (keine „hängenden" Activities).
        .task { sessionStore?.begin(session, resumable: resumable) }
        .onChange(of: session.index) {
            guard let store = sessionStore else { return }
            if session.isFinished { store.complete(session) } else { store.refresh(session) }
        }
        // Gesammelten Wochen-Log sichern, wenn die Runde vorzeitig verlassen wird
        // (Schließen/Swipe-Dismiss) oder die App in den Hintergrund geht (dann feuert
        // `onDisappear` nicht). Am Rundenende flusht die Session selbst.
        .onDisappear { session.flushProgress() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { session.flushProgress() }
        }
    }

    /// Beendet die Live Activity und schließt danach den Lernvorgang.
    private func handleClose() {
        sessionStore?.finish(session)
        onClose()
    }

    /// Ausgang des Endgegner-Kampfes für den Ergebnis-Screen – nur im Boss-Modus.
    private var bossOutcome: BossOutcome? {
        guard session.isBossMode else { return nil }
        return session.bossBattle.playerWon ? .victory : .defeat
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.m) {
            Image(systemName: "square.dashed")
                .font(.system(size: 52))
                .foregroundStyle(Theme.brandStart)
            Text(L(session.isClozeOnly ? "practice.cloze.empty" : "practice.noWords"))
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

    @ViewBuilder
    private func modeView(for item: PracticeItem) -> some View {
        let onAnswer: (Bool) -> Void = { correct in
            withAnimation { session.submit(correct: correct) }
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
}

/// Fortschrittsleiste eines Lernvorgangs (Position, Treffer/Fehler, Balken).
struct PracticeProgressHeader: View {
    let session: PracticeSession

    private var progress: Double {
        Double(session.index) / Double(max(session.total, 1))
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.s) {
            HStack {
                Text("\(session.position) / \(session.total)")
                    .font(.appSubheadline.weight(.semibold))
                Spacer()
                Label("\(session.correctCount)", systemImage: "checkmark")
                    .foregroundStyle(LearningStatus.learned.color)
                Label("\(session.wrongCount)", systemImage: "xmark")
                    .foregroundStyle(Theme.wrong)
            }
            .font(.appCaption.weight(.medium))

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.surfaceMuted)
                    Capsule().fill(Theme.brandGradient)
                        .frame(width: geo.size.width * progress)
                }
            }
            .frame(height: 8)
        }
        .padding(.horizontal, Theme.Spacing.m)
        .padding(.top, Theme.Spacing.s)
    }
}

/// Zusammenfassung am Ende eines Lernvorgangs: Genauigkeit, Streak, falsche und
/// aufgestiegene Wörter, plus gezieltes Nachüben der falschen.
struct PracticeSummaryView: View {
    let session: PracticeSession
    /// Ausgang des Endgegner-Kampfes; `nil` = normale Runde (Standard-Hero).
    var bossOutcome: BossOutcome?
    let onRestart: () -> Void
    let onRetryWrong: () -> Void
    let onClose: () -> Void

    @State private var appeared = false

    private var streak: Int { StreakStore.displayStreak() }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.l) {
                hero
                Text(L(bossOutcome?.titleKey ?? "practice.finished"))
                    .font(.appLargeTitle)
                    .multilineTextAlignment(.center)

                statRow
                Text(L("practice.finishedSummary", session.correctCount, session.wrongCount))
                    .font(.appSubheadline)
                    .foregroundStyle(.secondary)

                if !session.leveledUpVocabs.isEmpty {
                    wordList(title: L("practice.summary.leveledUp"),
                             systemImage: "arrow.up.circle.fill",
                             tint: LearningStatus.learned.color,
                             vocabs: session.leveledUpVocabs)
                }
                if !session.missedVocabs.isEmpty {
                    wordList(title: L("practice.summary.missed"),
                             systemImage: "xmark.circle.fill",
                             tint: Theme.wrong,
                             vocabs: session.missedVocabs)
                }

                actions
            }
            .padding(Theme.Spacing.l)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { appeared = true }
        }
    }

    /// Kopf-Symbol des Ergebnis-Screens: Party-Popper für normale Runden, im
    /// Endgegner-Modus stattdessen ein Sieg-/Niederlage-Emoji.
    @ViewBuilder
    private var hero: some View {
        if let bossOutcome {
            Text(bossOutcome.emoji)
                .font(.system(size: 64))
                .scaleEffect(appeared ? 1 : 0.4)
                .rotationEffect(.degrees(appeared ? 0 : -20))
        } else {
            Image(systemName: "party.popper.fill")
                .font(.system(size: 64))
                .foregroundStyle(Theme.brandGradient)
                .scaleEffect(appeared ? 1 : 0.4)
                .rotationEffect(.degrees(appeared ? 0 : -20))
        }
    }

    private var statRow: some View {
        HStack(spacing: Theme.Spacing.s) {
            StatTile(value: "\(session.accuracy)%", label: L("practice.summary.accuracy"),
                     systemImage: "target", tint: Theme.brandStart)
            StatTile(value: "\(session.correctCount)", label: L("home.stat.learned"),
                     systemImage: "checkmark", tint: LearningStatus.learned.color)
            if streak > 0 {
                StatTile(value: "\(streak)", label: L("practice.summary.streak"),
                         systemImage: "flame.fill", tint: Theme.brandEnd)
            }
        }
    }

    private func wordList(title: String, systemImage: String, tint: Color, vocabs: [Vocab]) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Label(title, systemImage: systemImage)
                .font(.appHeadline)
                .foregroundStyle(tint)
            ForEach(vocabs) { vocab in
                HStack {
                    Text(vocab.word).font(.appBody.weight(.medium))
                    Spacer()
                    Text(vocab.meaning).font(.appSubheadline).foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(padding: Theme.Spacing.m)
    }

    private var actions: some View {
        VStack(spacing: Theme.Spacing.s) {
            if session.missedVocabs.isEmpty {
                Button(action: onRestart) {
                    Label(L("practice.restart"), systemImage: "arrow.clockwise")
                }
                .buttonStyle(.primary)
            } else {
                Button(action: onRetryWrong) {
                    Label(L("practice.retryWrong"), systemImage: "arrow.uturn.backward")
                }
                .buttonStyle(.primary)
                Button(action: onRestart) {
                    Label(L("practice.restart"), systemImage: "arrow.clockwise")
                }
                .buttonStyle(.secondary)
            }
            Button(action: onClose) {
                Text(L("common.done"))
            }
            .buttonStyle(.secondary)
        }
    }
}

/// Große Karte für das abgefragte Wort – farbiger Verlauf, gerundete Schrift.
struct PromptCard: View {
    let text: String
    var subtitle: String?
    /// Wenn gesetzt, erscheint ein Vorlese-Button (koreanisches Wort). Nur übergeben,
    /// wenn der Prompt selbst das Wort ist – sonst würde er die Antwort verraten.
    var spokenText: String?

    var body: some View {
        VStack(spacing: Theme.Spacing.s) {
            HStack(spacing: Theme.Spacing.s) {
                Text(text)
                    .font(.appDisplay(44))
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.5)
                if let spokenText {
                    SpeakButton(text: spokenText, font: .appTitle2, tint: .white)
                }
            }
            if let subtitle {
                Text(subtitle)
                    .font(.appHeadline)
                    .opacity(0.9)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.xl + 8)
        .padding(.horizontal, Theme.Spacing.m)
        .background(Theme.brandGradientSoft, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .foregroundStyle(.white)
        .shadow(color: Theme.brandStart.opacity(0.3), radius: 16, y: 8)
    }
}

// MARK: - Endgegner-Modus (Issue #89)

/// Ausgang eines Endgegner-Kampfes für den Ergebnis-Screen.
enum BossOutcome {
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

/// Kampf-Kopfzeile im Endgegner-Modus: Boss (Name der einzigen Gruppe oder
/// generisch) mit HP-Leiste plus Herz-Anzeige der verbleibenden Leben. Rein
/// visuell – die Werte kommen aus `session.bossBattle`.
struct BossBattleHeader: View {
    let session: PracticeSession

    /// Ab dieser Lebenszahl wird kompakt „❤️ ×N" statt einzelner Herzen gezeigt.
    private static let heartsThreshold = 6

    private var battle: BossBattle { session.bossBattle }

    private var tint: Color {
        session.bossGroup.map { Color(hex: $0.colorHex) } ?? Theme.brandStart
    }

    private var bossName: String {
        session.bossGroup?.name ?? L("practice.boss.generic")
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.s) {
            HStack(spacing: Theme.Spacing.s) {
                Text("🐲")
                    .font(.system(size: 34))
                    .phaseAnimator([1.0, 0.82, 1.0], trigger: session.correctCount) { view, scale in
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
