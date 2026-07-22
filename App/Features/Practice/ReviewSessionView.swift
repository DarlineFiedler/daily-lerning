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
    @AppStorage("reviewWordLimit") private var wordLimitRaw = 0

    @State private var direction: PracticeDirection = .mixed
    @State private var modes: Set<PracticeMode> = []
    @State private var wordLimit: Int?
    @State private var session: PracticeSession?

    /// Heute noch offene Wörter (lernen bzw. wiederholen) – gleiche Logik wie die Home-Karte.
    private var dueVocabs: [Vocab] { DailyPlan.today(from: allVocabs).words }

    /// So viele Wörter werden diesen Durchgang tatsächlich abgefragt (Begrenzung
    /// berücksichtigt). Die übrigen bleiben für heute offen und tauchen beim
    /// nächsten Öffnen erneut im Pool auf.
    private var effectiveCount: Int {
        ReviewSelection(wordLimit: wordLimit).effectiveCount(poolCount: dueVocabs.count)
    }

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
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                DirectionModeSelection(direction: $direction, modes: $modes)
                WordLimitSelection(wordLimit: $wordLimit)
            }
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

            Text(L("group.wordCount", effectiveCount))
                .font(.appCaption)
                .foregroundStyle(.secondary)
        }
        .padding(Theme.Spacing.m)
        .background(.ultraThinMaterial)
    }

    /// Lädt die gemerkte Auswahl. Nicht (mehr) verfügbare Modi – z.B. Hören ohne
    /// installierte koreanische Stimme – werden ausgefiltert.
    private func loadSelection() {
        let selection = ReviewSelection.load(directionRaw: directionRaw, modesRaw: modesRaw,
                                             wordLimitRaw: wordLimitRaw)
        direction = selection.direction
        modes = selection.modes
        wordLimit = selection.wordLimit
    }

    /// Merkt die Auswahl und startet die Session über die heute fälligen Wörter.
    /// Bei gesetzter Wortanzahl nimmt die Session nur einen Teil des Pools; die
    /// übrigen Wörter bleiben für heute offen und erscheinen beim nächsten Öffnen
    /// erneut (siehe `DailyPlan`).
    private func start() {
        let due = dueVocabs
        guard !due.isEmpty else { return }
        let selection = ReviewSelection(direction: direction, modes: modes, wordLimit: wordLimit)
        directionRaw = selection.direction.rawValue
        modesRaw = selection.modesRaw
        wordLimitRaw = selection.wordLimitRaw
        session = PracticeSession(
            vocabs: due,
            distractorPool: allVocabs,
            config: PracticeConfig(statuses: [], direction: direction, modes: modes,
                                   wordLimit: wordLimit),
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
        .navigationTitle(L("review.config.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(L("common.close")) { dismiss() }
            }
        }
    }
}
