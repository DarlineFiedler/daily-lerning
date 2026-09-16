import SwiftData
import SwiftUI
import UniformTypeIdentifiers
import WidgetKit

/// Tab 4: Einstellungen – Sprache (Runtime-Umschaltung) und Lock-Screen-Widget.
struct SettingsView: View {
    // Bewusst NICHT via `@Environment(LocalizationManager.self)`: Wird die Umgebung beim
    // (mehrfach) gepushten Screen kurzzeitig ohne dieses Objekt neu ausgewertet, führt der
    // fehlende Environment-Eintrag zu einem harten `EnvironmentValues`-Trap (Absturz beim
    // Öffnen von „Dein Ziel"). Das geteilte Singleton ist ohnehin dieselbe Instanz, die
    // RootView injiziert – so kann der Zugriff nie ins Leere greifen.
    private let localization = LocalizationManager.shared
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
    @State private var backupFile: ShareFile?
    /// Zu teilende CSV-Exportdatei (löst das Share-Sheet aus).
    @State private var csvFile: ShareFile?
    @State private var showRestore = false
    @State private var restoreMessage: String?
    /// Eingelesene, noch nicht angewandte Sicherung – löst den Bestätigungsdialog aus.
    @State private var pendingRestore: PendingRestore?

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

    @AppStorage(BadgeKeys.enabled, store: AppGroup.defaults)
    private var badgeEnabled = false

    /// Steuert den Bestätigungsdialog für „Alles zurücksetzen".
    @State private var showResetConfirm = false

    var body: some View {
        @Bindable var localization = localization // lokale Bindung fürs Sprach-Segment

        // Kein eigener NavigationStack: SettingsView wird aus IchView in dessen Stack
        // gepusht. Ein zweiter, verschachtelter Stack ließ das Pushen von Unterseiten
        // (z. B. „Dein Ziel") einfrieren.
        Form {
                // MARK: Anzeige / Sprache
                Section {
                    PaperSegmented(
                        options: LocalizationManager.AppLanguage.allCases,
                        title: { L($0.displayNameKey) },
                        selection: $localization.language
                    )
                } header: {
                    SectionLabel(L("settings.display.section"))
                }

                // MARK: Widget
                Section {
                    VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                        Text(L("settings.widget.interval"))
                            .font(.appBody)
                            .foregroundStyle(Theme.ink)
                        PaperSegmented(options: WidgetSettings.intervalOptions,
                                       title: intervalLabel, selection: $interval)
                    }

                    Toggle(isOn: $showMeaning) {
                        Text(L("settings.widget.showMeaning"))
                            .font(.appBody)
                            .foregroundStyle(Theme.ink)
                    }
                    .tint(Theme.leaf)
                } header: {
                    SectionLabel(L("settings.widget.section"))
                } footer: {
                    HandNote(L("settings.widget.count", widgetVocabs.count) + " " + L("settings.widget.hint"),
                             size: 16, color: Theme.inkSecondary, angle: 0)
                }

                // MARK: Erinnerung
                Section {
                    Toggle(isOn: $reminderEnabled) {
                        Text(L("settings.reminder.enable"))
                            .font(.appBody)
                            .foregroundStyle(Theme.ink)
                    }
                    .tint(Theme.leaf)
                    if reminderEnabled {
                        DatePicker(selection: reminderTime, displayedComponents: .hourAndMinute) {
                            Text(L("settings.reminder.time"))
                                .font(.appBody)
                                .foregroundStyle(Theme.ink)
                        }
                    }
                    Toggle(isOn: $badgeEnabled) {
                        Text(L("settings.badge.enable"))
                            .font(.appBody)
                            .foregroundStyle(Theme.ink)
                    }
                    .tint(Theme.leaf)
                } header: {
                    SectionLabel(L("settings.reminder.section"))
                } footer: {
                    HandNote(L("settings.reminder.hint") + " " + L("settings.badge.hint"),
                             size: 16, color: Theme.inkSecondary, angle: 0)
                }

                // MARK: Ziel
                // Nur der Einstieg; die Picker und ihre Erklärung (Footer) leben in
                // GoalSettingsView, damit „Wert 0 = deaktiviert" dort steht, wo auch
                // die Picker sind (siehe [[GoalSettingsView]]).
                Section {
                    NavigationLink {
                        GoalSettingsView()
                    } label: {
                        Text(L("settings.goal.section"))
                            .font(.appBody)
                            .foregroundStyle(Theme.ink)
                    }
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
                        SectionLabel(L("wordpacks.section"))
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
                        Button {
                            exportCSV()
                        } label: {
                            Label(L("settings.data.export"), systemImage: "square.and.arrow.up")
                        }
                    }
                } header: {
                    SectionLabel(L("settings.data.section"))
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
                    SectionLabel(L("settings.backup.section"))
                } footer: {
                    Text(L("settings.backup.hint"))
                }

                // MARK: Über
                Section {
                    LabeledContent(L("settings.about.version"), value: appVersion)
                } header: {
                    SectionLabel(L("settings.about.section"))
                }

                // MARK: Zurücksetzen (ganz unten)
                Section {
                    Button(role: .destructive) {
                        showResetConfirm = true
                    } label: {
                        Text(L("settings.reset.button"))
                            .font(.appBody)
                            .frame(maxWidth: .infinity)
                    }
                } footer: {
                    HandNote(L("settings.reset.hint"), size: 16,
                             color: Theme.inkSecondary, angle: 0)
                }
            }
            .sheet(isPresented: $showImport) { VocabImportView() }
            .sheet(item: $backupFile) { file in
                ActivityView(items: [file.url])
            }
            .sheet(item: $csvFile) { file in
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
            .confirmationDialog(L("settings.backup.restore"),
                                isPresented: pendingRestoreBinding,
                                titleVisibility: .visible,
                                presenting: pendingRestore) { pending in
                Button(L("settings.backup.confirm.action"), role: .destructive) { confirmRestore(pending.backup) }
                Button(L("common.cancel"), role: .cancel) { pendingRestore = nil }
            } message: { pending in
                Text(L("settings.backup.confirm",
                       pending.backup.vocabs.count, pending.backup.groups.count))
            }
            .alert(packMessage ?? "", isPresented: packAlertBinding) {
                Button(L("common.done"), role: .cancel) { packMessage = nil }
            }
            .confirmationDialog(L("settings.reset.confirm"),
                                isPresented: $showResetConfirm,
                                titleVisibility: .visible) {
                Button(L("settings.reset.action"), role: .destructive) {
                    AppReset.factoryReset(context: context)
                }
                Button(L("common.cancel"), role: .cancel) {}
            } message: {
                Text(L("settings.reset.message"))
            }
            .onAppear { wordPacks = WordPack.loadBundled() }
            .scrollContentBackground(.hidden)
            // Zusätzlicher unterer Rand, damit die letzte Sektion („Alles zurücksetzen")
            // über der schwebenden Üben-FAB/Tab-Leiste sichtbar bleibt (Issue: verdeckt).
            .contentMargins(.bottom, 96, for: .scrollContent)
            .paperBackground()
            .navigationTitle(L("tab.settings"))
            .onChange(of: interval) { refreshWidget() }
            .onChange(of: showMeaning) { refreshWidget() }
            .onChange(of: localization.language) {
                AchievementService.recordEvent(\.languageChanged, context: context) // „Einstellungs-Entdecker"
            }
            .onChange(of: reminderEnabled) { _, enabled in
                if enabled {
                    Task {
                        if await NotificationScheduler.requestAuthorization() {
                            NotificationScheduler.schedule(hour: reminderHour, minute: reminderMinute)
                        } else {
                            reminderEnabled = false // Berechtigung verweigert
                        }
                    }
                } else {
                    NotificationScheduler.cancel()
                }
            }
            .onChange(of: reminderHour) { rescheduleReminder() }
            .onChange(of: reminderMinute) { rescheduleReminder() }
            .onChange(of: badgeEnabled) { _, enabled in
                if enabled {
                    Task {
                        if await NotificationScheduler.requestAuthorization() {
                            BadgeUpdater.refresh(context: context)
                        } else {
                            badgeEnabled = false // Berechtigung verweigert
                        }
                    }
                } else {
                    BadgeUpdater.setBadge(0)
                }
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
        AppContentRefresh.afterVocabChange(context: context)
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

    /// Bindung, die den Überschreib-Bestätigungsdialog zeigt, sobald eine Sicherung eingelesen ist.
    private var pendingRestoreBinding: Binding<Bool> {
        Binding { pendingRestore != nil } set: { if !$0 { pendingRestore = nil } }
    }

    // MARK: - Wortpakete

    /// Importiert die angegebenen Pakete jeweils in eine Gruppe mit dem Paketnamen
    /// (Dubletten werden übersprungen) und zeigt anschließend eine Ergebnis-Meldung.
    private func importPacks(_ packs: [WordPack]) {
        var total = VocabImporter.Result(added: 0, updated: 0, skipped: 0)
        for pack in packs {
            // Result definiert nur '+', kein '+=' – daher kein Shorthand möglich.
            // swiftlint:disable:next shorthand_operator
            total = total + VocabImporter.importRows(
                pack.rows, intoGroupNamed: pack.name, context: context, existingGroups: allGroups
            )
        }
        context.saveOrLog()
        AppContentRefresh.afterVocabChange(context: context)
        packMessage = L("wordpacks.result", total.added, total.updated, total.skipped)
    }

    /// Baut den CSV-Export erst beim Antippen (nicht bei jeder `body`-Auswertung)
    /// und teilt ihn als Datei.
    private func exportCSV() {
        guard let url = try? VocabCSV.exportFile(allVocabs) else {
            restoreMessage = L("settings.export.error")
            return
        }
        csvFile = ShareFile(url: url)
    }

    private func exportBackup() {
        guard let url = try? VocabBackup.exportFile(groups: allGroups, vocabs: allVocabs) else {
            restoreMessage = L("settings.backup.error")
            return
        }
        backupFile = ShareFile(url: url)
    }

    private func restoreBackup(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let url = urls.first else { return }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        do {
            // Größe prüfen, BEVOR die Datei in den Speicher geladen wird – nur so
            // wird eine riesige (evtl. fremde) Datei nicht erst komplett allokiert.
            let bytes = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
            try VocabBackup.validateFileSize(bytes)
            let data = try Data(contentsOf: url)
            // Nicht sofort anwenden: erst kurz bestätigen lassen, da vorhandene Wörter
            // per id überschrieben werden (Datensicherheit + Transparenz über die Menge).
            pendingRestore = PendingRestore(backup: try VocabBackup.decode(data))
        } catch VocabBackup.BackupError.tooLarge, VocabBackup.BackupError.fileTooLarge {
            restoreMessage = L("settings.backup.tooLarge")
        } catch VocabBackup.BackupError.unsupportedVersion {
            restoreMessage = L("settings.backup.outdated")
        } catch {
            restoreMessage = L("settings.backup.error")
        }
    }

    /// Spielt die zuvor eingelesene Sicherung tatsächlich ein (nach Bestätigung).
    private func confirmRestore(_ backup: VocabBackup) {
        backup.apply(into: context)
        AppContentRefresh.afterVocabChange(context: context)
        let message = L("settings.backup.restored", backup.vocabs.count, backup.groups.count)
        // Erst im nächsten Runloop setzen: der Bestätigungsdialog wird im selben
        // Zyklus geschlossen; ein direkt gesetzter Alert würde von SwiftUI sonst
        // verschluckt und der Nutzer sähe keine Erfolgsmeldung.
        DispatchQueue.main.async { restoreMessage = message }
    }
}

/// Identifizierbarer Wrapper um eine eingelesene, noch zu bestätigende Sicherung
/// (`VocabBackup` ist selbst nicht `Identifiable`) fürs `.confirmationDialog(presenting:)`.
private struct PendingRestore: Identifiable {
    let backup: VocabBackup
    let id = UUID()
}

/// Identifizierbarer Wrapper um eine zu teilende Datei-URL fürs `.sheet(item:)`
/// (Sicherung wie auch CSV-Export).
private struct ShareFile: Identifiable {
    let url: URL
    var id: String { url.path }
}

#Preview {
    NavigationStack { SettingsView() }
        .environment(LocalizationManager.shared)
        .modelContainer(PersistenceController.preview)
}
