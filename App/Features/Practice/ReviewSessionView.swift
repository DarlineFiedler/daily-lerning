import SwiftData
import SwiftUI

/// Gruppenübergreifende Wiederholung aller heute fälligen Wörter (SRS-lite).
/// Vor dem Start lässt sich Richtung + Modi wählen (z.B. Hören abwählen, wenn man
/// gerade nicht hören kann); die Auswahl wird gemerkt. Nutzt danach dieselbe
/// `PracticeSession`-Engine wie das gruppenbasierte Üben – nur mit dem „heute
/// fällig"-Wort-Pool aus `DailyPlan`.
struct ReviewSessionView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var allVocabs: [Vocab]

    /// Gemerkte Auswahl (App-übergreifend). Richtung als rawValue, Modi als
    /// CSV der rawValues – leer = alle Modi (wie bisheriges Verhalten).
    @AppStorage("reviewDirection") private var directionRaw = PracticeDirection.mixed.rawValue
    @AppStorage("reviewModes") private var modesRaw = ""

    @State private var direction: PracticeDirection = .mixed
    @State private var modes: Set<PracticeMode> = []
    @State private var session: PracticeSession?

    /// Heute noch offene Wörter (lernen bzw. wiederholen) – gleiche Logik wie die Home-Karte.
    private var dueVocabs: [Vocab] { DailyPlan.today(from: allVocabs).words }

    var body: some View {
        NavigationStack {
            Group {
                if let session {
                    PracticeContainerView(session: session, onClose: { dismiss() })
                } else if dueVocabs.isEmpty {
                    emptyState
                } else {
                    configStep
                }
            }
            .background(Theme.background.ignoresSafeArea())
        }
        .onAppear(perform: loadSelection)
    }

    // MARK: - Auswahl-Schritt

    private var configStep: some View {
        ScrollView {
            DirectionModeSelection(direction: $direction, modes: $modes)
                .padding(Theme.Spacing.m)
        }
        .navigationTitle(L("review.config.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(L("common.close")) { dismiss() }
            }
        }
        .safeAreaInset(edge: .bottom) { startBar }
    }

    private var startBar: some View {
        VStack(spacing: 6) {
            Button(action: start) {
                Label(L("common.start"), systemImage: "play.fill")
            }
            .buttonStyle(.primary)

            Text(L("group.wordCount", dueVocabs.count))
                .font(.appCaption)
                .foregroundStyle(.secondary)
        }
        .padding(Theme.Spacing.m)
        .background(.ultraThinMaterial)
    }

    /// Lädt die gemerkte Auswahl. Nicht (mehr) verfügbare Modi – z.B. Hören ohne
    /// installierte koreanische Stimme – werden ausgefiltert.
    private func loadSelection() {
        let selection = ReviewSelection.load(directionRaw: directionRaw, modesRaw: modesRaw)
        direction = selection.direction
        modes = selection.modes
    }

    /// Merkt die Auswahl und startet die Session über die heute fälligen Wörter.
    private func start() {
        let due = dueVocabs
        guard !due.isEmpty else { return }
        let selection = ReviewSelection(direction: direction, modes: modes)
        directionRaw = selection.direction.rawValue
        modesRaw = selection.modesRaw
        session = PracticeSession(
            vocabs: due,
            distractorPool: allVocabs,
            config: PracticeConfig(statuses: [], direction: direction, modes: modes),
            context: context
        )
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
