import SwiftData
import SwiftUI

/// Startet ohne Konfig-Schritt eine gruppenübergreifende Wiederholung aller heute
/// fälligen Wörter (SRS-lite). Nutzt dieselbe `PracticeSession`-Engine wie das
/// gruppenbasierte Üben – nur mit anderem Wort-Pool (alle Modi, gemischte Richtung).
struct ReviewSessionView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var allVocabs: [Vocab]

    @State private var session: PracticeSession?

    /// Heute noch offene Wörter (lernen bzw. wiederholen) – gleiche Logik wie die Home-Karte.
    private var dueVocabs: [Vocab] { DailyPlan.today(from: allVocabs).words }

    var body: some View {
        NavigationStack {
            Group {
                if let session {
                    PracticeContainerView(session: session, onClose: { dismiss() })
                } else {
                    emptyState
                }
            }
            .background(Theme.background.ignoresSafeArea())
        }
        .onAppear {
            guard session == nil else { return }
            let due = dueVocabs
            guard !due.isEmpty else { return }
            session = PracticeSession(
                vocabs: due,
                distractorPool: allVocabs,
                config: PracticeConfig(statuses: [], direction: .mixed, modes: []),
                context: context
            )
        }
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.m) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 52))
                .foregroundStyle(LearningStatus.learned.color)
            Text(L("review.empty"))
                .font(.appBody)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button(L("common.done")) { dismiss() }
                .buttonStyle(.primary)
                .padding(.horizontal, Theme.Spacing.xl)
        }
        .padding(Theme.Spacing.l)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(L("common.close")) { dismiss() }
            }
        }
    }
}
