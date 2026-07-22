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
                    if !history.isEmpty { historySection }
                }
                .padding(Theme.Spacing.m)
                .padding(.bottom, Theme.Spacing.xl)
            }
            .background(Theme.background.ignoresSafeArea())
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
        HStack(spacing: Theme.Spacing.s) {
            StatTile(value: "\(streak)", label: L("streak.detail.current"),
                     systemImage: "flame.fill", tint: Theme.brandEnd)
            StatTile(value: "\(longest)", label: L("streak.detail.longest"),
                     systemImage: "trophy.fill", tint: Theme.brandStart)
            StatTile(value: "\(jokers)/\(maxJokers)", label: L("streak.detail.jokers"),
                     systemImage: "snowflake", tint: Theme.statusAlmostLearned)
        }
    }

    // MARK: - Joker-Erklärung

    private var jokerCard: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.m) {
            Image(systemName: "snowflake")
                .font(.appTitle2)
                .foregroundStyle(Theme.statusAlmostLearned)
            VStack(alignment: .leading, spacing: 4) {
                Text(L("streak.detail.joker.title"))
                    .font(.appHeadline)
                    .foregroundStyle(.primary)
                Text(L("streak.detail.joker.explainer", maxJokers))
                    .font(.appSubheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(padding: Theme.Spacing.l)
    }

    // MARK: - Kalender

    private var calendarSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            SectionHeader(L("streak.calendar.title"))
            StreakCalendarView(activeDays: activeDays, jokerUses: jokerUses)
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
