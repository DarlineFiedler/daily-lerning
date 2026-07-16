import SwiftUI
import SwiftData
import WidgetKit

/// Tab 4: Einstellungen – Sprache (Runtime-Umschaltung) und Lock-Screen-Widget.
struct SettingsView: View {
    @Environment(LocalizationManager.self) private var localization
    @Environment(\.modelContext) private var context

    @Query(filter: #Predicate<Vocab> { $0.includeInWidget == true })
    private var widgetVocabs: [Vocab]

    @Query private var allVocabs: [Vocab]
    @State private var showImport = false

    @AppStorage(WidgetSettingsKeys.interval, store: AppGroup.defaults)
    private var interval = 30
    @AppStorage(WidgetSettingsKeys.showMeaning, store: AppGroup.defaults)
    private var showMeaning = true
    @AppStorage(WidgetSettingsKeys.showMeaningOnTap, store: AppGroup.defaults)
    private var showMeaningOnTap = false

    @AppStorage(ReminderKeys.enabled, store: AppGroup.defaults)
    private var reminderEnabled = false
    @AppStorage(ReminderKeys.hour, store: AppGroup.defaults)
    private var reminderHour = 19
    @AppStorage(ReminderKeys.minute, store: AppGroup.defaults)
    private var reminderMinute = 0

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

                // MARK: Erinnerung
                Section {
                    Toggle(isOn: $reminderEnabled) {
                        Label(L("settings.reminder.enable"), systemImage: "bell.badge")
                    }
                    if reminderEnabled {
                        DatePicker(selection: reminderTime, displayedComponents: .hourAndMinute) {
                            Label(L("settings.reminder.time"), systemImage: "clock.badge")
                        }
                    }
                } header: {
                    Text(L("settings.reminder.section"))
                } footer: {
                    Text(L("settings.reminder.hint"))
                }

                // MARK: Daten
                Section {
                    Button {
                        showImport = true
                    } label: {
                        Label(L("settings.data.import"), systemImage: "square.and.arrow.down")
                    }
                    if !allVocabs.isEmpty {
                        ShareLink(
                            item: VocabCSV.export(allVocabs),
                            preview: SharePreview(L("settings.data.export"))
                        ) {
                            Label(L("settings.data.export"), systemImage: "square.and.arrow.up")
                        }
                    }
                } header: {
                    Text(L("settings.data.section"))
                } footer: {
                    Text(L("settings.data.hint"))
                }

                // MARK: Über
                Section(L("settings.about.section")) {
                    LabeledContent(L("settings.about.version"), value: appVersion)
                }
            }
            .sheet(isPresented: $showImport) { VocabImportView() }
            .scrollContentBackground(.hidden)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle(L("tab.settings"))
            .onChange(of: interval) { refreshWidget() }
            .onChange(of: showMeaning) { refreshWidget() }
            .onChange(of: showMeaningOnTap) { refreshWidget() }
            .onChange(of: reminderEnabled) { _, enabled in
                if enabled {
                    Task {
                        if await NotificationScheduler.requestAuthorization() {
                            NotificationScheduler.schedule(hour: reminderHour, minute: reminderMinute)
                        } else {
                            reminderEnabled = false   // Berechtigung verweigert
                        }
                    }
                } else {
                    NotificationScheduler.cancel()
                }
            }
            .onChange(of: reminderHour) { rescheduleReminder() }
            .onChange(of: reminderMinute) { rescheduleReminder() }
        }
    }

    /// DatePicker-Brücke: speichert nur Stunde/Minute, kein volles Datum.
    private var reminderTime: Binding<Date> {
        Binding {
            Calendar.current.date(bySettingHour: reminderHour, minute: reminderMinute, second: 0, of: .now) ?? .now
        } set: { newValue in
            let c = Calendar.current.dateComponents([.hour, .minute], from: newValue)
            reminderHour = c.hour ?? 19
            reminderMinute = c.minute ?? 0
        }
    }

    private func rescheduleReminder() {
        guard reminderEnabled else { return }
        NotificationScheduler.schedule(hour: reminderHour, minute: reminderMinute)
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
