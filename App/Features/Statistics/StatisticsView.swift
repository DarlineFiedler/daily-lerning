import SwiftData
import SwiftUI

/// Tab 4: Statistik-Übersicht (global + pro Gruppe) als bunte Kacheln und Karten.
struct StatisticsView: View {
    @Query private var vocabs: [Vocab]
    @Query(sort: \VocabGroup.sortOrder) private var groups: [VocabGroup]

    @State private var showAchievements = false

    var body: some View {
        // Kein eigener NavigationStack: aus IchView in dessen Stack gepusht.
        Group {
                // Archivierte Gruppen sind „pausiert" und zählen – wie überall sonst
                // (Widget, Garten, App-Icon-Badge) – nicht in die Statistik. Einmal je
                // Render filtern und die Teilmengen nach unten reichen.
                let activeVocabs = vocabs.filter { $0.group?.isArchived != true }
                let activeGroups = groups.filter { !$0.isArchived }
                if activeVocabs.isEmpty {
                    emptyState
                } else {
                    // Status-Verteilung einmal je Render berechnen, statt sie in
                    // mehreren computed properties erneut zu filtern.
                    let counts = activeVocabs.statusCounts()
                    let learned = counts[.learned] ?? 0
                    let rate = Int(round(Double(learned) / Double(activeVocabs.count) * 100))
                    ScrollView {
                        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                            overallSection(total: activeVocabs.count, counts: counts,
                                           learned: learned, rate: rate)
                            trendSection
                            heatmapSection
                            if !activeGroups.isEmpty { byGroupSection(activeGroups) }
                        }
                        .padding(Theme.Spacing.m)
                    }
                }
            }
            .paperBackground()
            .navigationTitle(L("tab.stats"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAchievements = true
                    } label: {
                        Label(L("ach.title"), systemImage: "trophy.fill")
                    }
                }
            }
            .sheet(isPresented: $showAchievements) { NavigationStack { AchievementsView() } }
    }

    // MARK: - Gesamt

    private func overallSection(total: Int, counts: [LearningStatus: Int], learned: Int, rate: Int) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            SectionHeader(L("stats.overall"))
            StatTileRow {
                StatTile(value: "\(total)", label: L("stats.total"),
                         systemImage: "text.book.closed.fill", tint: Theme.brandStart)
                StatTile(value: "\(learned)", label: L("status.learned"),
                         systemImage: "checkmark.seal.fill", tint: LearningStatus.learned.color)
                StatTile(value: "\(rate)%", label: L("home.stat.rate"),
                         systemImage: "chart.pie.fill", tint: Theme.brandEnd)
            }
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
    }

    // MARK: - Lernkurve (Zeitverlauf)

    private var trendSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            SectionHeader(L("stats.trend.title"))
            LearningCurveView()
        }
    }

    // MARK: - Aktivitäts-Heatmap

    private var heatmapSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            SectionHeader(L("stats.heatmap.title"))
            ActivityHeatmapView()
        }
    }

    // MARK: - Nach Gruppe

    private func byGroupSection(_ activeGroups: [VocabGroup]) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            SectionHeader(L("stats.byGroup"))
            ForEach(activeGroups) { group in
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
        group.vocabs.statusCounts()
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
    NavigationStack { StatisticsView() }
        .modelContainer(PersistenceController.preview)
}
