import SwiftUI
import WidgetKit

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

    /// Welches Ziel gerade per Freitext-Eingabe bearbeitet wird (`nil` = keins).
    private enum GoalField { case weekly, daily }
    @State private var editingField: GoalField?
    @State private var customText = ""

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
                goalRow(
                    titleKey: "settings.goal.weekly",
                    systemImage: "calendar",
                    value: $weeklyGoal,
                    options: GoalOptions.weekly,
                    field: .weekly
                )
                goalRow(
                    titleKey: "settings.goal.daily",
                    systemImage: "sun.max",
                    value: $dailyGoal,
                    options: GoalOptions.daily,
                    field: .daily
                )
            } footer: {
                Text(L("settings.goal.footer"))
            }
        }
        .navigationTitle(L("settings.goal.section"))
        .navigationBarTitleDisplayMode(.inline)
        // Zieländerung wirkt sich direkt auf den Ring des Streak-Widgets aus.
        .onChange(of: goalMetricRaw) { reloadStreakWidget() }
        .onChange(of: weeklyGoal) { reloadStreakWidget() }
        .onChange(of: dailyGoal) { reloadStreakWidget() }
        .alert(L("settings.goal.customPrompt"), isPresented: customAlertPresented) {
            TextField(L("settings.goal.customPlaceholder"), text: $customText)
                #if os(iOS)
                    .keyboardType(.numberPad)
                #endif
            Button(L("common.cancel"), role: .cancel) {}
            Button(L("common.save")) { applyCustom() }
        } message: {
            Text(L("settings.goal.customHint"))
        }
    }

    /// Eine Zielzeile: Preset-Auswahl per Menü plus „Eigener Wert…" für freie Eingabe.
    /// Ein bereits gesetzter Wert außerhalb der Presets bleibt korrekt sichtbar, da das
    /// Label immer den tatsächlichen `value` anzeigt.
    private func goalRow(titleKey: String, systemImage: String,
                         value: Binding<Int>, options: [Int], field: GoalField) -> some View {
        Menu {
            Picker(selection: value) {
                ForEach(options, id: \.self) { option in
                    Text(goalValueLabel(option)).tag(option)
                }
            } label: { EmptyView() }
            Button {
                customText = value.wrappedValue == 0 ? "" : "\(value.wrappedValue)"
                editingField = field
            } label: {
                Label(L("settings.goal.custom"), systemImage: "pencil")
            }
        } label: {
            LabeledContent {
                Text(goalValueLabel(value.wrappedValue))
                    .foregroundStyle(Theme.brandStart)
            } label: {
                Label(L(titleKey), systemImage: systemImage)
            }
        }
    }

    /// Bindung, die das Ziel-Freitext-Alert öffnet/schließt (leitet aus `editingField` ab).
    private var customAlertPresented: Binding<Bool> {
        Binding(get: { editingField != nil }, set: { if !$0 { editingField = nil } })
    }

    /// Übernimmt die eingegebene Zahl. Gültig sind `0…maxCustom` (0 = Ziel aus);
    /// leere oder ungültige Eingaben lassen den Wert unverändert.
    private func applyCustom() {
        defer { editingField = nil }
        let trimmed = customText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let entered = Int(trimmed), entered >= 0 else { return }
        let clamped = min(entered, GoalOptions.maxCustom)
        switch editingField {
        case .weekly: weeklyGoal = clamped
        case .daily: dailyGoal = clamped
        case nil: break
        }
    }

    private func reloadStreakWidget() {
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetKind.streak)
    }

    /// Label für die Ziel-Picker: `0` bedeutet „deaktiviert".
    private func goalValueLabel(_ value: Int) -> String {
        value == 0 ? L("settings.goal.off") : "\(value)"
    }
}

#Preview {
    NavigationStack { GoalSettingsView() }
}
