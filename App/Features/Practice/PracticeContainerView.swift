import SwiftUI

/// Führt durch einen Lernvorgang und zeigt je Wort die passende Modus-View.
struct PracticeContainerView: View {
    @State var session: PracticeSession
    /// Beendet den gesamten Lernvorgang (schließt das Practice-Sheet).
    var onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            if let item = session.currentItem {
                progressHeader
                ScrollView {
                    modeView(for: item)
                        .padding(Theme.Spacing.m)
                        .id(session.index) // erzwingt frische State pro Wort
                }
            } else {
                PracticeSummaryView(
                    session: session,
                    onRestart: { withAnimation { session.restart() } },
                    onRetryWrong: { withAnimation { session.retryWrong() } },
                    onClose: onClose
                )
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
        // Haptik für die wichtigsten Lern-Momente (richtig/falsch).
        .sensoryFeedback(.success, trigger: session.correctCount)
        .sensoryFeedback(.error, trigger: session.wrongCount)
        .overlay(alignment: .top) {
            AchievementUnlockBanner(achievements: session.newlyUnlocked)
        }
    }

    private var progressHeader: some View {
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

    private var progress: Double {
        Double(session.index) / Double(max(session.total, 1))
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
        }
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
