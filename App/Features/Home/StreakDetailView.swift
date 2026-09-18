import SwiftUI

/// Detailansicht zu Streak & Joker: aktueller/längster Streak, verfügbare
/// Streak-Freeze-Joker und die Historie der per Joker geretteten Tage.
struct StreakDetailView: View {
    @Environment(\.dismiss) private var dismiss

    let streak: Int
    let longest: Int
    let jokers: Int
    let maxJokers: Int
    let jokerUses: [Date]
    var activeDays: [Date] = []

    /// Geretteter Tage, neueste zuerst.
    private var history: [Date] { jokerUses.sorted(by: >) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.l) {
                    stats
                    jokerCard
                    calendarSection
                    heatmapSection
                    if !history.isEmpty { historySection }
                    HandNote(L("streak.detail.jokerFooter"), size: 18,
                             color: Theme.inkSecondary, angle: -1)
                        .frame(maxWidth: .infinity)
                        .padding(.top, Theme.Spacing.s)
                }
                .padding(Theme.Spacing.m)
                .padding(.bottom, Theme.Spacing.xl)
            }
            .paperBackground()
            .navigationTitle(L("streak.detail.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("common.done")) { dismiss() }
                }
            }
        }
    }

    // MARK: - Streak-Kennzahlen

    private var stats: some View {
        VStack(spacing: Theme.Spacing.xs) {
            Text("🔥").font(.system(size: 52))
            Text("\(streak)")
                .font(.appDisplay(52))
                .foregroundStyle(Theme.ink)
            Text(L("streak.detail.daysInARow"))
                .font(.appMono(12))
                .tracking(1.5)
                .textCase(.uppercase)
                .foregroundStyle(Theme.inkSecondary)
            HandNote(L("streak.detail.recordShort", longest), color: Theme.vermillion, angle: -1)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Joker-Erklärung

    private var jokerCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("❄️ " + L("streak.detail.joker.title"))
                        .font(.appHeadline)
                        .foregroundStyle(Theme.ink)
                    Text(L("streak.detail.joker.covers"))
                        .font(.appMono(11))
                        .foregroundStyle(Theme.inkSecondary)
                }
                Spacer()
                Text("\(jokers) / \(maxJokers)")
                    .font(.appMono(15))
                    .foregroundStyle(Theme.leaf)
            }
            HStack(spacing: Theme.Spacing.s) {
                ForEach(0 ..< maxJokers, id: \.self) { i in
                    Text("❄️")
                        .font(.system(size: 22))
                        .opacity(i < jokers ? 1 : 0.22)
                }
            }
            if !history.isEmpty {
                Text(L("streak.detail.joker.usedCount", history.count))
                    .font(.appMono(11))
                    .foregroundStyle(Theme.inkSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    // MARK: - Kalender

    private var calendarSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            SectionHeader(L("streak.calendar.title"))
            StreakCalendarView(activeDays: activeDays, jokerUses: jokerUses)
        }
    }

    // MARK: - Aktivitäts-Heatmap

    private var heatmapSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            SectionHeader(L("stats.heatmap.title"))
            ActivityHeatmapView()
        }
    }

    // MARK: - Einsatz-Historie

    private var historySection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            SectionHeader(L("streak.detail.history"))
            VStack(spacing: 0) {
                ForEach(Array(history.enumerated()), id: \.offset) { index, day in
                    if index > 0 { Divider() }
                    HStack(spacing: Theme.Spacing.m) {
                        Image(systemName: "snowflake")
                            .font(.appSubheadline)
                            .foregroundStyle(Theme.statusAlmostLearned)
                        Text(L("streak.detail.history.entry", formatted(day)))
                            .font(.appBody)
                            .foregroundStyle(.primary)
                        Spacer()
                    }
                    .padding(.vertical, Theme.Spacing.s)
                }
            }
            .cardStyle(padding: Theme.Spacing.m)
        }
    }

    private func formatted(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.wide).year()
            .locale(LocalizationManager.shared.localeForFormatting))
    }
}

#Preview {
    StreakDetailView(
        streak: 12, longest: 30, jokers: 2, maxJokers: 3,
        jokerUses: [.now.addingTimeInterval(-86_400 * 3), .now.addingTimeInterval(-86_400 * 10)],
        activeDays: (0 ..< 12).compactMap { [1, 2, 4, 5].contains($0) ? nil : .now.addingTimeInterval(-86_400 * Double($0)) }
    )
}
