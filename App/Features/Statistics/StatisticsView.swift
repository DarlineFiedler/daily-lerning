import SwiftUI
import SwiftData

/// Tab 3: Statistik-Übersicht (global + pro Gruppe).
struct StatisticsView: View {
    @Query private var vocabs: [Vocab]
    @Query(sort: \VocabGroup.sortOrder) private var groups: [VocabGroup]

    private var overallCounts: [LearningStatus: Int] {
        Dictionary(uniqueKeysWithValues: LearningStatus.allCases.map { status in
            (status, vocabs.filter { $0.status == status }.count)
        })
    }

    var body: some View {
        NavigationStack {
            Group {
                if vocabs.isEmpty {
                    ContentUnavailableView {
                        Label(L("tab.stats"), systemImage: "chart.bar")
                    } description: {
                        Text(L("stats.empty"))
                    }
                } else {
                    List {
                        Section(L("stats.overall")) {
                            LabeledContent(L("stats.total"), value: "\(vocabs.count)")
                            StatusDistributionBar(counts: overallCounts, height: 12)
                                .padding(.vertical, 4)
                            ForEach(LearningStatus.allCases) { status in
                                HStack {
                                    StatusDot(status: status, size: 12)
                                    Text(L(status.titleKey))
                                    Spacer()
                                    Text("\(overallCounts[status] ?? 0)")
                                        .foregroundStyle(.secondary)
                                        .monospacedDigit()
                                }
                            }
                        }

                        if !groups.isEmpty {
                            Section(L("stats.byGroup")) {
                                ForEach(groups) { group in
                                    GroupStatRow(group: group)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(L("tab.stats"))
        }
    }
}

/// Statistikzeile für eine Gruppe.
private struct GroupStatRow: View {
    let group: VocabGroup

    private var counts: [LearningStatus: Int] {
        Dictionary(uniqueKeysWithValues: LearningStatus.allCases.map { ($0, group.count(of: $0)) })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                GroupColorDot(colorHex: group.colorHex)
                Text(group.name).font(.subheadline.weight(.medium))
                Spacer()
                Text("\(group.count(of: .learned))/\(group.vocabCount)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            if group.vocabCount > 0 {
                StatusDistributionBar(counts: counts)
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    StatisticsView()
        .modelContainer(PersistenceController.preview)
}
