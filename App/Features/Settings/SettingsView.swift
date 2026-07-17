import SwiftUI
import SwiftData
import WidgetKit
import UniformTypeIdentifiers

/// Tab 4: Einstellungen – Sprache (Runtime-Umschaltung) und Lock-Screen-Widget.
struct SettingsView: View {
    @Environment(LocalizationManager.self) private var localization
    @Environment(\.modelContext) private var context

    @Query(filter: #Predicate<Vocab> { $0.includeInWidget == true })
    private var widgetVocabs: [Vocab]

    @Query private var allVocabs: [Vocab]
    @Query(sort: \VocabGroup.sortOrder) private var allGroups: [VocabGroup]
    @State private var showImport = false

    /// Mitgelieferte Vokabel-Pakete (aus dem `WordPacks/`-Ordner im Bundle).
    @State private var wordPacks: [WordPack] = []
    /// Ergebnis-Meldung nach einem Paket-Import (löst den Alert aus).
    @State private var packMessage: String?

    /// Zu teilende Sicherungsdatei (löst das Share-Sheet aus).
    @State private var backupFile: BackupFile?
    @State private var showRestore = false
    @State private var restoreMessage: String?

    @AppStorage(WidgetSettingsKeys.interval, store: AppGroup.defaults)
    private var interval = 30
    @AppStorage(WidgetSettingsKeys.showMeaning, store: AppGroup.defaults)
    private var showMeaning = true

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

                // MARK: Wortpakete
                if !wordPacks.isEmpty {
                    Section {
                        ForEach(wordPacks) { pack in
                            HStack {
                                Text(pack.name)
                                Spacer()
                                Text(L("wordpacks.count", pack.count))
                                    .foregroundStyle(.secondary)
                                Button {
                                    importPacks([pack])
                                } label: {
                                    Image(systemName: "plus.circle.fill")
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                        Button {
                            importPacks(wordPacks)
                        } label: {
                            Label(L("wordpacks.importAll"), systemImage: "square.and.arrow.down.on.square")
                        }
                    } header: {
                        Text(L("wordpacks.section"))
                    } footer: {
                        Text(L("wordpacks.hint"))
                    }
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

                // MARK: Sicherung
                Section {
                    if !allVocabs.isEmpty {
                        Button {
                            exportBackup()
                        } label: {
                            Label(L("settings.backup.export"), systemImage: "arrow.down.doc")
                        }
                    }
                    Button {
                        showRestore = true
                    } label: {
                        Label(L("settings.backup.restore"), systemImage: "arrow.up.doc")
                    }
                } header: {
                    Text(L("settings.backup.section"))
                } footer: {
                    Text(L("settings.backup.hint"))
                }

                // MARK: Über
                Section(L("settings.about.section")) {
                    LabeledContent(L("settings.about.version"), value: appVersion)
                }
            }
            .sheet(isPresented: $showImport) { VocabImportView() }
            .sheet(item: $backupFile) { file in
                ActivityView(items: [file.url])
            }
            .fileImporter(isPresented: $showRestore,
                          allowedContentTypes: [.json],
                          allowsMultipleSelection: false) { result in
                restoreBackup(result)
            }
            .alert(restoreMessage ?? "", isPresented: restoreAlertBinding) {
                Button(L("common.done"), role: .cancel) { restoreMessage = nil }
            }
            .alert(packMessage ?? "", isPresented: packAlertBinding) {
                Button(L("common.done"), role: .cancel) { packMessage = nil }
            }
            .onAppear { wordPacks = WordPack.loadBundled() }
            .scrollContentBackground(.hidden)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle(L("tab.settings"))
            .onChange(of: interval) { refreshWidget() }
            .onChange(of: showMeaning) { refreshWidget() }
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

    // MARK: - Sicherung

    /// Bindung, die den Bestätigungs-Alert zeigt, sobald eine Meldung vorliegt.
    private var restoreAlertBinding: Binding<Bool> {
        Binding { restoreMessage != nil } set: { if !$0 { restoreMessage = nil } }
    }

    /// Bindung für den Ergebnis-Alert nach einem Paket-Import.
    private var packAlertBinding: Binding<Bool> {
        Binding { packMessage != nil } set: { if !$0 { packMessage = nil } }
    }

    // MARK: - Wortpakete

    /// Importiert die angegebenen Pakete jeweils in eine Gruppe mit dem Paketnamen
    /// (Dubletten werden übersprungen) und zeigt anschließend eine Ergebnis-Meldung.
    private func importPacks(_ packs: [WordPack]) {
        var total = VocabImporter.Result(added: 0, skipped: 0)
        for pack in packs {
            total = total + VocabImporter.importRows(
                pack.rows, intoGroupNamed: pack.name, context: context, existingGroups: allGroups
            )
        }
        context.saveOrLog()
        WidgetSnapshotWriter.refresh(context: context)
        packMessage = L("wordpacks.result", total.added, total.skipped)
    }

    private func exportBackup() {
        guard let url = try? VocabBackup.exportFile(groups: allGroups, vocabs: allVocabs) else {
            restoreMessage = L("settings.backup.error")
            return
        }
        backupFile = BackupFile(url: url)
    }

    private func restoreBackup(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let url = urls.first else { return }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        guard let data = try? Data(contentsOf: url),
              let backup = try? VocabBackup.decode(data) else {
            restoreMessage = L("settings.backup.error")
            return
        }
        backup.apply(into: context)
        WidgetSnapshotWriter.refresh(context: context)
        restoreMessage = L("settings.backup.restored", backup.vocabs.count, backup.groups.count)
    }
}

/// Identifizierbarer Wrapper um die Sicherungs-URL fürs `.sheet(item:)`.
private struct BackupFile: Identifiable {
    let url: URL
    var id: String { url.path }
}

#Preview {
    SettingsView()
        .environment(LocalizationManager.shared)
        .modelContainer(PersistenceController.preview)
}
