import SwiftUI

/// Statistik-Screen des persönlichen Tages-/Wochenziels – erscheint beim Antippen der
/// Ziel-Karte auf dem Home-Screen (statt wie früher direkt der Einstellungen). Zeigt
/// Kennzahlen (Ziel-Streak, Erfüllungsquote, erreichte Wochenziele, Trefferquote/Summen),
/// einen Ziel-Kalender ([[GoalCalendarView]]) und die Aktivitäts-Heatmap. Die
/// Ziel-Einstellungen ([[GoalSettingsView]]) sind über das Zahnrad-Icon erreichbar.
struct GoalStatsView: View {
    @Environment(\.dismiss) private var dismiss
    var today: Date = .now

    @State private var showSettings = false
    /// Beim Öffnen einmal aus den Stores geladen (statt bei jeder Body-Auswertung neu
    /// zu dekodieren); der Screen ist ohnehin nur eine Momentaufnahme.
    @State private var stats = GoalStats.current()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                    metricsSection(stats)
                    calendarSection(stats)
                    heatmapSection
                }
                .padding(Theme.Spacing.m)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle(L("goalstats.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("common.done")) { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Label(L("goalstats.settings.open"), systemImage: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                NavigationStack {
                    GoalSettingsView()
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button(L("common.done")) { showSettings = false }
                            }
                        }
                }
            }
        }
    }

    // MARK: - Kennzahlen

    private func metricsSection(_ stats: GoalStats) -> some View {
        let streak = stats.goalStreak(asOf: today)
        let best = stats.bestGoalStreak(asOf: today)
        let rate = stats.completionRate(inMonthOf: today, asOf: today)
        let weeklyReached = stats.weeklyGoalsReachedCount(weeks: 13, asOf: today)
        let days = stats.activity.days
        let correct = days.reduce(0) { $0 + $1.correctCount }
        let wrong = days.reduce(0) { $0 + $1.wrongCount }
        let answered = correct + wrong
        let accuracy = answered == 0 ? nil : Int((Double(correct) / Double(answered) * 100).rounded())
        let practiced = days.reduce(0) { $0 + $1.practicedIDs.count }

        return VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            SectionHeader(L("goalstats.overview"))
            HStack(spacing: Theme.Spacing.s) {
                StatTile(value: "\(streak)", label: L("goalstats.streak"),
                         systemImage: "flame.fill", tint: Theme.brandEnd)
                StatTile(value: "\(best)", label: L("goalstats.streak.best"),
                         systemImage: "crown.fill", tint: Theme.brandStart)
                StatTile(value: percentText(rate), label: L("goalstats.rate"),
                         systemImage: "chart.pie.fill", tint: LearningStatus.learned.color)
            }
            HStack(spacing: Theme.Spacing.s) {
                StatTile(value: "\(weeklyReached)", label: L("goalstats.weekly.reached"),
                         systemImage: "star.fill", tint: LearningStatus.learned.color)
                StatTile(value: "\(practiced)", label: L("goalstats.practiced"),
                         systemImage: "checkmark.circle.fill", tint: Theme.brandStart)
                StatTile(value: accuracy.map { "\($0)%" } ?? "–", label: L("goalstats.accuracy"),
                         systemImage: "target", tint: Theme.brandEnd)
            }
        }
    }

    /// Erfüllungsquote (0…1) als Prozenttext; „–", wenn im Monat kein Ziel galt.
    private func percentText(_ fraction: Double?) -> String {
        guard let fraction else { return "–" }
        return "\(Int((fraction * 100).rounded()))%"
    }

    // MARK: - Kalender

    private func calendarSection(_ stats: GoalStats) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            SectionHeader(L("goalstats.calendar.title"))
            GoalCalendarView(stats: stats, today: today)
        }
    }

    // MARK: - Heatmap

    private var heatmapSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            SectionHeader(L("stats.heatmap.title"))
            ActivityHeatmapView()
        }
    }
}

#Preview {
    GoalStatsView()
}
