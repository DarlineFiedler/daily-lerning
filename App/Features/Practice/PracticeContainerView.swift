import SwiftUI

/// Führt durch einen Lernvorgang und zeigt je Wort die passende Modus-View.
struct PracticeContainerView: View {
    @State var session: PracticeSession
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            if let item = session.currentItem {
                progressHeader
                ScrollView {
                    modeView(for: item)
                        .padding(Theme.Spacing.m)
                        .id(session.index)   // erzwingt frische State pro Wort
                }
            } else {
                PracticeSummaryView(
                    correct: session.correctCount,
                    wrong: session.wrongCount,
                    onRestart: { withAnimation { session.restart() } },
                    onClose: { dismiss() }
                )
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(L("common.close")) { dismiss() }
            }
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
                    .foregroundStyle(.red)
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
        }
    }
}

/// Zusammenfassung am Ende eines Lernvorgangs.
struct PracticeSummaryView: View {
    let correct: Int
    let wrong: Int
    let onRestart: () -> Void
    let onClose: () -> Void

    @State private var appeared = false

    var body: some View {
        VStack(spacing: Theme.Spacing.l) {
            Spacer()
            Image(systemName: "party.popper.fill")
                .font(.system(size: 72))
                .foregroundStyle(Theme.brandGradient)
                .scaleEffect(appeared ? 1 : 0.4)
                .rotationEffect(.degrees(appeared ? 0 : -20))
            Text(L("practice.finished"))
                .font(.appLargeTitle)
            Text(L("practice.finishedSummary", correct, wrong))
                .font(.appTitle3)
                .foregroundStyle(.secondary)
            Spacer()
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
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { appeared = true }
        }
    }
}

/// Große Karte für das abgefragte Wort – farbiger Verlauf, gerundete Schrift.
struct PromptCard: View {
    let text: String
    var subtitle: String?

    var body: some View {
        VStack(spacing: Theme.Spacing.s) {
            Text(text)
                .font(.appDisplay(44))
                .multilineTextAlignment(.center)
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
