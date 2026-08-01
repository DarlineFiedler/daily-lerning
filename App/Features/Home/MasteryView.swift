import SwiftData
import SwiftUI

/// „Beherrschung"-Screen (geöffnet aus der Quote-Kachel im Home-Dashboard):
/// großer Fortschritts-Ring mit der Gesamt-Lernquote, Status-Aufschlüsselung und
/// ein Ranking der Gruppen nach Beherrschung. Ergänzt die Statistik-Tab-Ansicht
/// (Zeitverlauf/Heatmap) um einen bewusst quoten-fokussierten Blick.
struct MasteryView: View {
    @Query private var vocabs: [Vocab]
    @Query(sort: \VocabGroup.sortOrder) private var groups: [VocabGroup]

    private var activeVocabs: [Vocab] { vocabs.filter { $0.group?.isArchived != true } }
    private var activeGroups: [VocabGroup] { groups.filter { !$0.isArchived } }

    var body: some View {
        let active = activeVocabs
        let counts = active.statusCounts()
        let learned = counts[.learned] ?? 0
        let fraction = active.isEmpty ? 0 : Double(learned) / Double(active.count)
        return ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                if active.isEmpty {
                    emptyState
                } else {
                    ringSection(fraction: fraction, learned: learned, total: active.count)
                    breakdownSection(counts: counts)
                    if !activeGroups.isEmpty { rankingSection }
                }
            }
            .padding(Theme.Spacing.m)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle(L("mastery.title"))
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Ring

    private func ringSection(fraction: Double, learned: Int, total: Int) -> some View {
        VStack(spacing: Theme.Spacing.m) {
            MasteryRing(fraction: fraction)
            Text("\(learned) / \(total) · \(L("mastery.ring.label"))")
                .font(.appSubheadline)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .cardStyle(padding: Theme.Spacing.l)
    }

    // MARK: - Status-Aufschlüsselung

    private func breakdownSection(counts: [LearningStatus: Int]) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            StatusDistributionBar(counts: counts, height: 14)
            ForEach(LearningStatus.allCases) { status in
                HStack {
                    StatusDot(status: status, size: 12)
                    Text(L(status.titleKey)).font(.appBody)
                    Spacer()
                    Text("\(counts[status] ?? 0)")
                        .font(.appBody.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
        }
        .cardStyle()
    }

    // MARK: - Gruppen-Ranking

    private var rankingSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            SectionHeader(L("mastery.ranking.title"))
            ForEach(rankedGroups) { group in
                NavigationLink { GroupDetailView(group: group) } label: {
                    MasteryRankRow(group: group)
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// Gruppen nach Beherrschungs-Anteil absteigend (leere Gruppen ans Ende).
    private var rankedGroups: [VocabGroup] {
        activeGroups.sorted { masteryFraction($0) > masteryFraction($1) }
    }

    private func masteryFraction(_ group: VocabGroup) -> Double {
        group.vocabCount > 0 ? Double(group.count(of: .learned)) / Double(group.vocabCount) : 0
    }

    // MARK: - Leerzustand

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.m) {
            Image(systemName: "chart.pie.fill")
                .font(.system(size: 52))
                .foregroundStyle(Theme.brandGradient)
            Text(L("stats.empty"))
                .font(.appBody)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Theme.Spacing.xl)
    }
}

/// Großer Kreis-Ring, der die Gesamt-Lernquote als Anteil darstellt.
private struct MasteryRing: View {
    let fraction: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.surfaceMuted, lineWidth: 18)
            Circle()
                .trim(from: 0, to: max(0, min(fraction, 1)))
                .stroke(Theme.brandGradient,
                        style: StrokeStyle(lineWidth: 18, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.6), value: fraction)
            VStack(spacing: 2) {
                Text("\(Int(round(fraction * 100)))%")
                    .font(.appDisplay(44))
                    .contentTransition(.numericText())
                Text(L("mastery.ring.label"))
                    .font(.appCaption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 180, height: 180)
        .padding(.vertical, Theme.Spacing.s)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(L("mastery.ring.label")) \(Int(round(fraction * 100)))%")
    }
}

/// Eine Ranking-Zeile: Gruppenfarbe, Name, in Gruppenfarbe getönter Balken und Prozent.
private struct MasteryRankRow: View {
    let group: VocabGroup

    private var fraction: Double {
        group.vocabCount > 0 ? Double(group.count(of: .learned)) / Double(group.vocabCount) : 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            HStack(spacing: Theme.Spacing.s) {
                GroupColorDot(colorHex: group.colorHex)
                Text(group.name).font(.appHeadline).lineLimit(1)
                Spacer()
                Text("\(Int(round(fraction * 100)))%")
                    .font(.appCaption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.surfaceMuted)
                    Capsule()
                        .fill(Color(hex: group.colorHex))
                        .frame(width: geo.size.width * max(0, min(fraction, 1)))
                }
            }
            .frame(height: 10)
        }
        .cardStyle()
    }
}

#Preview {
    NavigationStack {
        MasteryView()
    }
    .modelContainer(PersistenceController.preview)
}
