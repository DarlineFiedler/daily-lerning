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
                    onRestart: { withAnimation { session.restart() } },
                    onRetryWrong: { withAnimation { session.retryWrong() } },
                    onClose: handleClose
                )
            } else if let item = session.currentItem {
                PracticeProgressHeader(session: session)
                ScrollView {
                    modeView(for: item)
                        .padding(Theme.Spacing.m)
                        .id(session.index) // erzwingt frische State pro Wort
                }
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
        // Verstärktes Feedback an Kombo-Schwellen (5/10/…) – über die vorhandene
        // SwiftUI-API, kein neues UIKit. Haptik + kurzer System-Sound.
        .sensoryFeedback(trigger: session.currentCombo) { _, combo in
            PracticeSession.isComboMilestone(combo) ? .impact(weight: .medium) : nil
        }
        .onChange(of: session.currentCombo) { _, combo in
            if PracticeSession.isComboMilestone(combo) { SoundService.playComboMilestone() }
        }
        // Live-Kombo-Badge: nur während einer laufenden Karte, nicht-interaktiv, unter
        // dem Fortschritts-Header schwebend (stört den Lernfluss nicht). Weicht dem
        // Freischalt-Banner, das denselben oberen Bereich belegt, damit sich beide
        // nicht überlagern.
        .overlay(alignment: .top) {
            if session.currentItem != nil, session.newlyUnlocked.isEmpty {
                ComboBadge(combo: session.currentCombo)
                    .padding(.top, 72)
                    .allowsHitTesting(false)
            }
        }
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
    let onRestart: () -> Void
    let onRetryWrong: () -> Void
    let onClose: () -> Void

    @State private var appeared = false

    private var streak: Int { StreakStore.displayStreak() }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.l) {
                Image(systemName: "party.popper.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(Theme.brandGradient)
                    .scaleEffect(appeared ? 1 : 0.4)
                    .rotationEffect(.degrees(appeared ? 0 : -20))
                Text(L("practice.finished"))
                    .font(.appLargeTitle)

                if let newLevel = session.newLevel {
                    XPLevelUpBanner(level: newLevel)
                }

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

    /// Die je nach Rundenverlauf sichtbaren Kacheln (Genauigkeit & Treffer immer, XP/Kombo/
    /// Streak nur wenn > 0). Als Liste gebaut, damit sie sich auf mehrere Reihen verteilen
    /// lassen, statt bis zu fünf Kacheln in eine Reihe zu quetschen.
    private var statTiles: [StatTile] {
        var tiles = [
            StatTile(value: "\(session.accuracy)%", label: L("practice.summary.accuracy"),
                     systemImage: "target", tint: Theme.brandStart),
            StatTile(value: "\(session.correctCount)", label: L("home.stat.learned"),
                     systemImage: "checkmark", tint: LearningStatus.learned.color),
        ]
        if session.xpEarned > 0 {
            tiles.append(StatTile(value: "+\(session.xpEarned)", label: L("practice.summary.xp"),
                                  systemImage: "star.fill", tint: Theme.brandMid))
        }
        if session.maxCombo >= PracticeSession.comboBadgeMin {
            tiles.append(StatTile(value: "×\(session.maxCombo)", label: L("practice.summary.combo"),
                                  systemImage: "bolt.fill", tint: Theme.brandMid))
        }
        if streak > 0 {
            tiles.append(StatTile(value: "\(streak)", label: L("practice.summary.streak"),
                                  systemImage: "flame.fill", tint: Theme.brandEnd))
        }
        return tiles
    }

    /// Verteilt die Kacheln auf möglichst gleich große Reihen mit höchstens `maxPerRow`
    /// Kacheln (2–5 Kacheln → 1–2 Reihen), damit keine Reihe überfüllt wird.
    private func statTileRows(_ tiles: [StatTile], maxPerRow: Int = 3) -> [[StatTile]] {
        guard tiles.count > maxPerRow else { return tiles.isEmpty ? [] : [tiles] }
        let rowCount = Int((Double(tiles.count) / Double(maxPerRow)).rounded(.up))
        let perRow = Int((Double(tiles.count) / Double(rowCount)).rounded(.up))
        return stride(from: 0, to: tiles.count, by: perRow).map {
            Array(tiles[$0 ..< Swift.min($0 + perRow, tiles.count)])
        }
    }

    private var statRow: some View {
        VStack(spacing: Theme.Spacing.s) {
            ForEach(Array(statTileRows(statTiles).enumerated()), id: \.offset) { _, row in
                HStack(spacing: Theme.Spacing.s) {
                    ForEach(Array(row.enumerated()), id: \.offset) { _, tile in
                        tile
                    }
                }
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
