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
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                SectionLabel(L("settings.goal.section"))
                VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                    Text(L("settings.goal.metric"))
                        .font(.appBody)
                        .foregroundStyle(Theme.ink)
                    PaperSegmented(
                        options: GoalMetric.allCases,
                        title: { L($0.labelKey) },
                        selection: Binding(
                            get: { GoalMetric(rawValue: goalMetricRaw) ?? .practiced },
                            set: { goalMetricRaw = $0.rawValue }
                        )
                    )
                }
                Divider().overlay(Theme.hairline)
                goalRow(titleKey: "settings.goal.weekly", value: $weeklyGoal,
                        options: GoalOptions.weekly, field: .weekly)
                Divider().overlay(Theme.hairline)
                goalRow(titleKey: "settings.goal.daily", value: $dailyGoal,
                        options: GoalOptions.daily, field: .daily)
                HandNote(L("settings.goal.footer"), size: 17,
                         color: Theme.inkSecondary, angle: 0)
                    .padding(.top, Theme.Spacing.xs)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle()
            .padding(Theme.Spacing.m)
        }
        .paperBackground()
        .navigationTitle(L("settings.goal.section"))
        .navigationBarTitleDisplayMode(.inline)
        // Zieländerung wirkt sich direkt auf den Ring des Streak-Widgets aus.
        .onChange(of: goalMetricRaw) { goalDidChange() }
        .onChange(of: weeklyGoal) { goalDidChange() }
        .onChange(of: dailyGoal) { goalDidChange() }
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
    private func goalRow(titleKey: String,
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
            HStack {
                Text(L(titleKey))
                    .font(.appBody)
                    .foregroundStyle(Theme.ink)
                Spacer()
                Text(goalValueLabel(value.wrappedValue))
                    .font(.appMono(13))
                    .foregroundStyle(Theme.vermillion)
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
        guard let clamped = GoalOptions.normalizedCustom(customText) else { return }
        switch editingField {
        case .weekly: weeklyGoal = clamped
        case .daily: dailyGoal = clamped
        case nil: break
        }
    }

    /// Reaktion auf eine Ziel-Änderung: hält den heutigen Ziel-Snapshot (für den
    /// Statistik-Kalender) aktuell und lädt das Streak-Widget neu.
    private func goalDidChange() {
        GoalHistoryStore.snapshotToday()
        reloadStreakWidget()
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
