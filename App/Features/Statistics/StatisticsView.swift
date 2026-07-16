import SwiftUI
import SwiftData

/// Tab 4: Statistik-Übersicht (global + pro Gruppe) als bunte Kacheln und Karten.
struct StatisticsView: View {
    @Query private var vocabs: [Vocab]
    @Query(sort: \VocabGroup.sortOrder) private var groups: [VocabGroup]

    private var overallCounts: [LearningStatus: Int] {
        Dictionary(uniqueKeysWithValues: LearningStatus.allCases.map { status in
            (status, vocabs.filter { $0.status == status }.count)
        })
    }

    private var learnedCount: Int { overallCounts[.learned] ?? 0 }
    private var rate: Int {
        guard !vocabs.isEmpty else { return 0 }
        return Int(round(Double(learnedCount) / Double(vocabs.count) * 100))
    }

    var body: some View {
        NavigationStack {
            Group {
                if vocabs.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                            overallSection
                            if !groups.isEmpty { byGroupSection }
                        }
                        .padding(Theme.Spacing.m)
                    }
                }
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle(L("tab.stats"))
        }
    }

    // MARK: - Gesamt

    private var overallSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            SectionHeader(L("stats.overall"))
            HStack(spacing: Theme.Spacing.s) {
                StatTile(value: "\(vocabs.count)", label: L("stats.total"),
                         systemImage: "text.book.closed.fill", tint: Theme.brandStart)
                StatTile(value: "\(learnedCount)", label: L("status.learned"),
                         systemImage: "checkmark.seal.fill", tint: LearningStatus.learned.color)
                StatTile(value: "\(rate)%", label: L("home.stat.rate"),
                         systemImage: "chart.pie.fill", tint: Theme.brandEnd)
            }
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                StatusDistributionBar(counts: overallCounts, height: 14)
                ForEach(LearningStatus.allCases) { status in
                    HStack {
                        StatusDot(status: status, size: 12)
                        Text(L(status.titleKey)).font(.appBody)
                        Spacer()
                        Text("\(overallCounts[status] ?? 0)")
                            .font(.appBody.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
            }
            .cardStyle()
        }
    }

    // MARK: - Nach Gruppe

    private var byGroupSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            SectionHeader(L("stats.byGroup"))
            ForEach(groups) { group in
                GroupStatRow(group: group)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.m) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 52))
                .foregroundStyle(Theme.brandGradient)
            Text(L("stats.empty"))
                .font(.appBody)
                .foregroundStyle(.secondary)
        }
        .padding(Theme.Spacing.l)
    }
}

/// Statistikzeile für eine Gruppe als Karte.
private struct GroupStatRow: View {
    let group: VocabGroup

    private var counts: [LearningStatus: Int] {
        Dictionary(uniqueKeysWithValues: LearningStatus.allCases.map { ($0, group.count(of: $0)) })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            HStack(spacing: Theme.Spacing.s) {
                GroupColorDot(colorHex: group.colorHex)
                Text(group.name).font(.appHeadline)
                Spacer()
                Text("\(group.count(of: .learned))/\(group.vocabCount)")
                    .font(.appCaption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            if group.vocabCount > 0 {
                StatusDistributionBar(counts: counts)
            }
        }
        .cardStyle()
    }
}

#Preview {
    StatisticsView()
        .modelContainer(PersistenceController.preview)
}
