import SwiftUI

/// Fokussierter Einstellungs-Screen für das persönliche Tages-/Wochenziel.
///
/// Wird an zwei Stellen genutzt und teilt sich damit eine einzige Quelle für die
/// Ziel-Picker: als Unterseite der [[SettingsView]] (per `NavigationLink`) sowie als
/// Sheet, das beim Tippen auf die Ziel-Karte des Home-Screens erscheint.
///
/// Da Fortschritt (siehe `WeeklyReviewStore`) rein aus dem Aktivitäts-Log abgeleitet
/// wird, ändert das Anpassen eines Zielwerts hier ausschließlich die Zielmarke – die
/// bereits an diesem Tag/dieser Woche gezählten Wörter bleiben unverändert erhalten.
struct GoalSettingsView: View {
    @AppStorage(GoalKeys.metric, store: AppGroup.defaults)
    private var goalMetricRaw = GoalMetric.practiced.rawValue
    @AppStorage(GoalKeys.weekly, store: AppGroup.defaults)
    private var weeklyGoal = GoalOptions.defaultWeekly
    @AppStorage(GoalKeys.daily, store: AppGroup.defaults)
    private var dailyGoal = GoalOptions.defaultDaily

    var body: some View {
        Form {
            Section {
                Picker(selection: $goalMetricRaw) {
                    ForEach(GoalMetric.allCases) { metric in
                        Text(L(metric.labelKey)).tag(metric.rawValue)
                    }
                } label: {
                    Label(L("settings.goal.metric"), systemImage: "target")
                }
                Picker(selection: $weeklyGoal) {
                    ForEach(GoalOptions.weekly, id: \.self) { value in
                        Text(goalValueLabel(value)).tag(value)
                    }
                } label: {
                    Label(L("settings.goal.weekly"), systemImage: "calendar")
                }
                Picker(selection: $dailyGoal) {
                    ForEach(GoalOptions.daily, id: \.self) { value in
                        Text(goalValueLabel(value)).tag(value)
                    }
                } label: {
                    Label(L("settings.goal.daily"), systemImage: "sun.max")
                }
            } footer: {
                Text(L("settings.goal.footer"))
            }
        }
        .navigationTitle(L("settings.goal.section"))
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Label für die Ziel-Picker: `0` bedeutet „deaktiviert".
    private func goalValueLabel(_ value: Int) -> String {
        value == 0 ? L("settings.goal.off") : "\(value)"
    }
}

#Preview {
    NavigationStack { GoalSettingsView() }
}
