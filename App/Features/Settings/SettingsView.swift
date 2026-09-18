import SwiftData
import SwiftUI
import UniformTypeIdentifiers
import WidgetKit

/// Tab „Ich" → Einstellungen: Sprache, Lock-Screen-Widget, Erinnerung, Ziel, Wortpakete,
/// Daten/Sicherung, Reset.
///
/// Bewusst **kein `Form`/`List`**, sondern ein `ScrollView` mit Papier-Karten: Auf iOS 26
/// führte der Form-eigene Collection-View-Coordinator beim Pushen von Unterseiten
/// (Ich → Einstellungen → „Dein Ziel") zu einem Layout-Update-Hänger, den der Watchdog
/// nach 5s abschoss (0x8BADF00D). Der ScrollView-Aufbau umgeht diesen Coordinator ganz
/// und passt zudem zum Papier-Design (siehe [[IchView]]). Kein eigener NavigationStack –
/// SettingsView wird aus IchView in dessen Stack gepusht.
struct SettingsView: View {
    // Bewusst NICHT via `@Environment(LocalizationManager.self)`: ein fehlender
    // Environment-Eintrag beim gepushten Screen führte zu einem harten Trap. Das
    // geteilte Singleton ist dieselbe Instanz, die RootView injiziert.
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
    /// „Dein Ziel" wird als Sheet präsentiert statt gepusht: Ein dritter NavigationLink-
    /// Push in den Tab-Stack ließ die App auf iOS 26 im Layout-Update hängen (Watchdog-
    /// Kill). Ein Sheet öffnet einen eigenen Präsentationskontext und umgeht das.
    @State private var showGoal = false

    var body: some View {
        @Bindable var localization = localization // lokale Bindung fürs Sprach-Segment

        ScrollView {
            VStack(spacing: Theme.Spacing.m) {
                languageCard(localization: $localization.language)
                widgetCard
                reminderCard
                goalCard
                if !wordPacks.isEmpty { wordPacksCard }
                dataCard
                backupCard
                aboutCard
                resetSection
            }
            .padding(Theme.Spacing.m)
            // Genug Luft unten, damit die letzte Karte über der schwebenden Üben-FAB/
            // Tab-Leiste sichtbar bleibt.
            .padding(.bottom, Theme.Spacing.xl * 2)
        }
        .paperBackground()
        .navigationTitle(L("tab.settings"))
        .sheet(isPresented: $showGoal) {
            NavigationStack {
                GoalSettingsView()
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button(L("common.done")) { showGoal = false }
                        }
                    }
            }
        }
        .sheet(isPresented: $showImport) { VocabImportView() }
        .sheet(item: $backupFile) { file in ActivityView(items: [file.url]) }
        .sheet(item: $csvFile) { file in ActivityView(items: [file.url]) }
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

    // MARK: - Karten

    private func languageCard(localization: Binding<LocalizationManager.AppLanguage>) -> some View {
        card(L("settings.display.section")) {
            PaperSegmented(options: LocalizationManager.AppLanguage.allCases,
                           title: { L($0.displayNameKey) },
                           selection: localization)
        }
    }

    private var widgetCard: some View {
        card(L("settings.widget.section"),
             note: L("settings.widget.count", widgetVocabs.count) + " " + L("settings.widget.hint")) {
            Text(L("settings.widget.interval")).font(.appBody).foregroundStyle(Theme.ink)
            PaperSegmented(options: WidgetSettings.intervalOptions,
                           title: intervalLabel, selection: $interval)
            hairline
            Toggle(isOn: $showMeaning) {
                Text(L("settings.widget.showMeaning")).font(.appBody).foregroundStyle(Theme.ink)
            }
            .tint(Theme.leaf)
        }
    }

    private var reminderCard: some View {
        card(L("settings.reminder.section"),
             note: L("settings.reminder.hint") + " " + L("settings.badge.hint")) {
            Toggle(isOn: $reminderEnabled) {
                Text(L("settings.reminder.enable")).font(.appBody).foregroundStyle(Theme.ink)
            }
            .tint(Theme.leaf)
            if reminderEnabled {
                hairline
                DatePicker(selection: reminderTime, displayedComponents: .hourAndMinute) {
                    Text(L("settings.reminder.time")).font(.appBody).foregroundStyle(Theme.ink)
                }
            }
            hairline
            Toggle(isOn: $badgeEnabled) {
                Text(L("settings.badge.enable")).font(.appBody).foregroundStyle(Theme.ink)
            }
            .tint(Theme.leaf)
        }
    }

    private var goalCard: some View {
        Button { showGoal = true } label: {
            HStack {
                Text(L("settings.goal.section")).font(.appBody).foregroundStyle(Theme.ink)
                Spacer()
                Image(systemName: "chevron.right").font(.appCaption).foregroundStyle(Theme.inkMuted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .cardStyle()
        }
        .buttonStyle(.plain)
    }

    private var wordPacksCard: some View {
        card(L("wordpacks.section") + " · \(wordPacks.count)", note: L("wordpacks.hint")) {
            ForEach(wordPacks) { pack in
                HStack {
                    Text(pack.name).font(.appBody).foregroundStyle(Theme.ink)
                    Spacer()
                    Text("\(pack.count)").font(.appMono(12)).foregroundStyle(Theme.inkSecondary)
                    Button { importPacks([pack]) } label: {
                        Text("+").font(.appMono(18)).foregroundStyle(Theme.vermillion)
                    }
                    .buttonStyle(.plain)
                }
            }
            hairline
            Button { importPacks(wordPacks) } label: {
                Text(L("wordpacks.importAll")).font(.appBody).foregroundStyle(Theme.vermillion)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
        }
    }

    private var dataCard: some View {
        card(L("settings.data.section"), note: L("settings.data.hint")) {
            actionRow(L("settings.data.import")) { showImport = true }
            if !allVocabs.isEmpty {
                hairline
                actionRow(L("settings.data.export")) { exportCSV() }
            }
        }
    }

    private var backupCard: some View {
        card(L("settings.backup.section"), note: L("settings.backup.hint")) {
            if !allVocabs.isEmpty {
                actionRow(L("settings.backup.export")) { exportBackup() }
                hairline
            }
            actionRow(L("settings.backup.restore"), tint: Theme.vermillion) { showRestore = true }
        }
    }

    private var aboutCard: some View {
        HStack {
            Text(L("settings.about.version")).font(.appBody).foregroundStyle(Theme.inkSecondary)
            Spacer()
            Text(appVersion).font(.appMono(13)).foregroundStyle(Theme.inkMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private var resetSection: some View {
        VStack(spacing: Theme.Spacing.s) {
            Button(role: .destructive) { showResetConfirm = true } label: {
                Text(L("settings.reset.button"))
                    .font(.appBody)
                    .foregroundStyle(Theme.vermillion)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.s)
                    .cardStyle()
            }
            .buttonStyle(.plain)
            HandNote(L("settings.reset.hint"), size: 16, color: Theme.inkSecondary, angle: 0)
                .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Bausteine

    /// Papier-Karte mit Mono-Label und optionaler Handschrift-Fußnote.
    private func card<Content: View>(_ title: String, note: String? = nil,
                                     @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            SectionLabel(title)
            content()
            if let note {
                HandNote(note, size: 16, color: Theme.inkSecondary, angle: 0)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    /// Tippbare Aktionszeile mit Chevron (Import/Export/Sicherung).
    private func actionRow(_ title: String, tint: Color = Theme.ink,
                           action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title).font(.appBody).foregroundStyle(tint)
                Spacer()
                Image(systemName: "chevron.right").font(.appCaption).foregroundStyle(Theme.inkFaint)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var hairline: some View {
        Divider().overlay(Theme.hairline)
    }

    // MARK: - Ableitungen & Aktionen

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
