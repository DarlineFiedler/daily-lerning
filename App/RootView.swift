import SwiftData
import SwiftUI

/// Wurzel-View der v3-Optik: eigene 3-Tab-Navigation (Garten · Üben-FAB · Ich) statt
/// der bisherigen fünf System-Tabs. Der zentrale FAB startet die heutige Runde bzw.
/// öffnet die Rundenkonfiguration. Wird bei Sprachwechsel komplett neu aufgebaut
/// (`.id(localization.language)`), damit alle Texte aktualisieren.
struct RootView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase

    @Query(sort: \Vocab.createdAt) private var vocabs: [Vocab]

    @State private var localization = LocalizationManager.shared
    @State private var sessionStore = ActiveSessionStore()
    @State private var selectedTab: GardenTab = .garden
    @State private var deepLink: IdentifiableID?
    @State private var showReview = false
    @State private var showPracticeConfig = false
    @State private var showStreakDetail = false
    @State private var showStoreError = false

    private var dueCount: Int {
        DailyPlan.openWordCount(from: vocabs.filter { $0.group?.isArchived != true })
    }

    var body: some View {
        Group {
            switch selectedTab {
            case .garden: GardenHomeView()
            case .me: IchView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            GardenTabBar(selection: $selectedTab, dueCount: dueCount, onPractice: startPractice)
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
            WordRevealSheet(wordID: item.id)
        }
        .sheet(isPresented: $showReview) {
            ReviewSessionView()
        }
        .sheet(isPresented: $showPracticeConfig) {
            PracticeConfigView()
        }
        .sheet(isPresented: $showStreakDetail) {
            StreakDetailView(streak: StreakStore.displayStreak(),
                             longest: StreakStore.longest,
                             jokers: StreakStore.availableJokers(),
                             maxJokers: StreakStore.maxJokers,
                             jokerUses: StreakStore.jokerUses,
                             activeDays: StreakStore.activeDays)
        }
    }

    /// Üben-FAB: liegen fällige Wörter an, startet direkt die heutige Runde; sonst
    /// öffnet sich die Rundenkonfiguration zum freien Üben.
    private func startPractice() {
        if dueCount > 0 {
            showReview = true
        } else {
            showPracticeConfig = true
        }
    }
}

#Preview {
    RootView()
        .modelContainer(PersistenceController.preview)
}
