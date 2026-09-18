import SwiftData
import SwiftUI

/// Wurzel-View der v3-Optik: eigene 3-Tab-Navigation (Garten · Üben-FAB · Ich) statt
/// der bisherigen fünf System-Tabs. Der zentrale FAB öffnet immer die ausführliche
/// Rundenkonfiguration. Wird bei Sprachwechsel komplett neu aufgebaut
/// (`.id(localization.language)`), damit alle Texte aktualisieren.
struct RootView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase

    @State private var localization = LocalizationManager.shared
    @State private var sessionStore = ActiveSessionStore()
    @State private var selectedTab: GardenTab = .garden
    /// Wird pro Tab hochgezählt, wenn der bereits aktive Tab erneut getippt wird –
    /// über `.id(…)` baut das die Tab-Ansicht neu auf und setzt ihre Navigation zurück
    /// auf die Übersicht (poppt gepushte Screens wie Suche/Gruppen/Übersetzer).
    @State private var gardenResetID = 0
    @State private var meResetID = 0
    @State private var deepLink: IdentifiableID?
    @State private var showReview = false
    @State private var showPracticeConfig = false
    #if DEBUG
    @State private var showBossDebug = false
    @State private var showSearchDebug = false
    @State private var showDetailDebug = false
    @State private var showGoalDebug = false
    #endif
    @State private var showStreakDetail = false
    @State private var showStoreError = false

    /// Erststart abgeschlossen? Reaktiv über den geteilten UserDefaults-Store, damit der
    /// Abschluss des Onboardings sofort in den Garten wechselt.
    @AppStorage(OnboardingState.completedKey, store: AppGroup.defaults) private var onboardingDone = false

    var body: some View {
        Group {
            if !onboardingDone {
                OnboardingView(onFinish: { onboardingDone = true })
            } else {
                mainShell
            }
        }
        .tint(Theme.vermillion)
        .id(localization.language)
        .environment(localization)
        .environment(sessionStore)
        .environment(\.locale, localization.localeForFormatting)
        .task {
            if PersistenceController.storeOpenFailed {
                showStoreError = true
            } else {
                StoreMigration.runIfNeeded(into: context)
                SeedData.removeLegacySeedIfNeeded(from: context)
                #if DEBUG
                DemoSeed.insertIfRequestedAndEmpty(into: context)
                if CommandLine.arguments.contains("-uiTestOnboarding") {
                    onboardingDone = false
                } else if DemoSeed.isRequested {
                    onboardingDone = true // andere Debug-Screens am Erststart vorbei
                }
                if CommandLine.arguments.contains("-uiTestReview") { showReview = true }
                if CommandLine.arguments.contains("-uiTestPracticeConfig") { showPracticeConfig = true }
                // Vollständigen Reset testen: wischt alles und muss zur Begrüßung zurückführen.
                if CommandLine.arguments.contains("-uiTestReset") { AppReset.factoryReset(context: context) }
                if CommandLine.arguments.contains("-uiTestMeTab") { selectedTab = .me }
                if CommandLine.arguments.contains("-uiTestBoss") { showBossDebug = true }
                if CommandLine.arguments.contains("-uiTestSearch") { showSearchDebug = true }
                if CommandLine.arguments.contains("-uiTestDetail") { showDetailDebug = true }
                if CommandLine.arguments.contains("-uiTestGoal") { showGoalDebug = true }
                #endif
            }
            AppContentRefresh.onAppActive(context: context)
        }
        .alert(L("store.error.title"), isPresented: $showStoreError) {
            Button(L("common.done"), role: .cancel) {}
        } message: {
            Text(L("store.error.message"))
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                AppContentRefresh.onAppActive(context: context)
            }
        }
        .onOpenURL { url in
            if let id = DeepLink.wordID(from: url) {
                deepLink = IdentifiableID(id: id)
                AchievementService.recordEvent(\.widgetUsed, context: context) // „Widget-Fan"
            } else if DeepLink.isReview(url) {
                showReview = true
            } else if DeepLink.isSession(url) {
                showReview = sessionStore.active != nil
            } else if DeepLink.isStreak(url) {
                showStreakDetail = true
                AchievementService.recordEvent(\.widgetUsed, context: context) // „Widget-Fan"
            }
        }
        .sheet(item: $deepLink) { item in
            WordRevealSheet(wordID: item.id).modifier(SheetEnvironment(localization: localization, sessionStore: sessionStore))
        }
        .sheet(isPresented: $showReview) {
            ReviewSessionView().modifier(SheetEnvironment(localization: localization, sessionStore: sessionStore))
        }
        .sheet(isPresented: $showPracticeConfig) {
            PracticeConfigView().modifier(SheetEnvironment(localization: localization, sessionStore: sessionStore))
        }
        .sheet(isPresented: $showStreakDetail) {
            StreakDetailView(streak: StreakStore.displayStreak(),
                             longest: StreakStore.longest,
                             jokers: StreakStore.availableJokers(),
                             maxJokers: StreakStore.maxJokers,
                             jokerUses: StreakStore.jokerUses,
                             activeDays: StreakStore.activeDays)
                .modifier(SheetEnvironment(localization: localization, sessionStore: sessionStore))
        }
        #if DEBUG
        .sheet(isPresented: $showBossDebug) {
            let vocabs = (try? context.fetch(FetchDescriptor<Vocab>())) ?? []
            NavigationStack {
                BossBattleContainerView(
                    session: BossSession(
                        vocabs: vocabs, distractorPool: vocabs,
                        config: PracticeConfig(statuses: [], direction: .mixed, modes: [.multipleChoice],
                                               wordLimit: nil, meaningLanguage: nil,
                                               bossMode: true, examMode: false),
                        context: context
                    ),
                    onClose: { showBossDebug = false }
                )
            }
            .modifier(SheetEnvironment(localization: localization, sessionStore: sessionStore))
        }
        .sheet(isPresented: $showSearchDebug) {
            NavigationStack { SearchView() }
                .modifier(SheetEnvironment(localization: localization, sessionStore: sessionStore))
        }
        .sheet(isPresented: $showDetailDebug) {
            if let vocab = try? context.fetch(FetchDescriptor<Vocab>()).first {
                VocabDetailView(vocab: vocab, onEdit: {})
                    .modifier(SheetEnvironment(localization: localization, sessionStore: sessionStore))
            }
        }
        .sheet(isPresented: $showGoalDebug) {
            NavigationStack { GoalSettingsView() }
                .modifier(SheetEnvironment(localization: localization, sessionStore: sessionStore))
        }
        #endif
    }

    /// Das 3-Tab-Gerüst (Garten · Üben-FAB · Ich) nach abgeschlossenem Erststart.
    private var mainShell: some View {
        Group {
            switch selectedTab {
            case .garden: GardenHomeView().id(gardenResetID)
            case .me: IchView().id(meResetID)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            GardenTabBarContainer(selection: selectedTab,
                                  onSelect: selectTab, onPractice: startPractice)
        }
    }

    /// Tipp auf einen Seiten-Tab: ist er schon aktiv, zurück zur Übersicht (Navigation
    /// zurücksetzen); sonst zu ihm wechseln.
    private func selectTab(_ tab: GardenTab) {
        guard tab == selectedTab else { selectedTab = tab; return }
        switch tab {
        case .garden: gardenResetID += 1
        case .me: meResetID += 1
        }
    }

    /// Üben-FAB: öffnet immer die ausführliche Rundenkonfiguration („Runde vorbereiten")
    /// mit voller Auswahl (Beete, Wachstum, TOPIK, Richtung, Modi, Anzahl …). Die heutige
    /// Runde („Heute gießen", nur Pensum-Wörter mit Gelernt-Fallback) wird stattdessen über
    /// die Gieß-Karte im Garten gestartet.
    private func startPractice() {
        showPracticeConfig = true
    }
}

/// Reicht die für Sheets nötige Umgebung (Sprache, Locale, Session-Store) explizit
/// weiter. Bei der eigenen 3-Tab-Shell erben Sheets die `.environment`-Objekte nicht
/// zuverlässig – ohne diese Re-Injektion stürzt z.B. ReviewSessionView
/// (`@Environment(ActiveSessionStore.self)`) beim Öffnen ab.
private struct SheetEnvironment: ViewModifier {
    let localization: LocalizationManager
    let sessionStore: ActiveSessionStore

    func body(content: Content) -> some View {
        content
            .environment(localization)
            .environment(sessionStore)
            .environment(\.locale, localization.localeForFormatting)
    }
}

/// Kapselt die `@Query` für die Zahl fälliger Wörter. Dadurch lösen Vokabel-
/// änderungen nur ein Neuberechnen dieser schmalen Tab-Leiste aus – nicht der
/// kompletten RootView-Shell (Garten/Ich-Inhalt bleibt unberührt).
private struct GardenTabBarContainer: View {
    @Query(sort: \Vocab.createdAt) private var vocabs: [Vocab]
    let selection: GardenTab
    let onSelect: (GardenTab) -> Void
    let onPractice: () -> Void

    private var dueCount: Int {
        DailyPlan.openWordCount(from: vocabs.filter { $0.group?.isArchived != true })
    }

    var body: some View {
        GardenTabBar(selection: selection, dueCount: dueCount,
                     onSelect: onSelect, onPractice: onPractice)
    }
}

#Preview {
    RootView()
        .modelContainer(PersistenceController.preview)
}
