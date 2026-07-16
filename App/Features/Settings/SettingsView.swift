import SwiftUI
import SwiftData
import WidgetKit

/// Tab 4: Einstellungen – Sprache (Runtime-Umschaltung) und Lock-Screen-Widget.
struct SettingsView: View {
    @Environment(LocalizationManager.self) private var localization
    @Environment(\.modelContext) private var context

    @Query(filter: #Predicate<Vocab> { $0.includeInWidget == true })
    private var widgetVocabs: [Vocab]

    @AppStorage(WidgetSettingsKeys.interval, store: AppGroup.defaults)
    private var interval = 30
    @AppStorage(WidgetSettingsKeys.showMeaning, store: AppGroup.defaults)
    private var showMeaning = true
    @AppStorage(WidgetSettingsKeys.showMeaningOnTap, store: AppGroup.defaults)
    private var showMeaningOnTap = false

    var body: some View {
        @Bindable var localization = localization

        NavigationStack {
            Form {
                // MARK: Anzeige / Sprache
                Section(L("settings.display.section")) {
                    Picker(selection: $localization.language) {
                        ForEach(LocalizationManager.AppLanguage.allCases) { lang in
                            Text(L(lang.displayNameKey)).tag(lang)
                        }
                    } label: {
                        Label(L("settings.language"), systemImage: "globe")
                    }
                }

                // MARK: Widget
                Section {
                    Picker(selection: $interval) {
                        ForEach(WidgetSettings.intervalOptions, id: \.self) { minutes in
                            Text(intervalLabel(minutes)).tag(minutes)
                        }
                    } label: {
                        Label(L("settings.widget.interval"), systemImage: "clock")
                    }

                    Toggle(isOn: $showMeaning) {
                        Label(L("settings.widget.showMeaning"), systemImage: "text.alignleft")
                    }

                    Toggle(isOn: $showMeaningOnTap) {
                        Label(L("settings.widget.showMeaningOnTap"), systemImage: "hand.tap")
                    }
                } header: {
                    Text(L("settings.widget.section"))
                } footer: {
                    Text(L("settings.widget.count", widgetVocabs.count) + "\n" + L("settings.widget.hint"))
                }

                // MARK: Über
                Section(L("settings.about.section")) {
                    LabeledContent(L("settings.about.version"), value: appVersion)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle(L("tab.settings"))
            .onChange(of: interval) { refreshWidget() }
            .onChange(of: showMeaning) { refreshWidget() }
            .onChange(of: showMeaningOnTap) { refreshWidget() }
        }
    }

    private func intervalLabel(_ minutes: Int) -> String {
        minutes < 60 ? L("interval.min", minutes) : L("interval.hour", minutes / 60)
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }

    private func refreshWidget() {
        WidgetSnapshotWriter.refresh(context: context)
    }
}

#Preview {
    SettingsView()
        .environment(LocalizationManager.shared)
        .modelContainer(PersistenceController.preview)
}
