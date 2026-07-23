import SwiftData
import SwiftUI

/// Wurzel-View mit den fünf Haupt-Tabs. Wird bei Sprachwechsel komplett neu
/// aufgebaut (`.id(localization.language)`), damit alle Texte aktualisiert werden.
struct RootView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase

    @State private var localization = LocalizationManager.shared
    @State private var deepLink: IdentifiableID?
    @State private var showReview = false
    @State private var showStoreError = false

    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label(L("tab.home"), systemImage: "house.fill") }

            GroupListView()
                .tabItem { Label(L("tab.groups"), systemImage: "rectangle.stack.fill") }

            SearchView()
                .tabItem { Label(L("tab.search"), systemImage: "magnifyingglass") }

            StatisticsView()
                .tabItem { Label(L("tab.stats"), systemImage: "chart.bar.fill") }

            SettingsView()
                .tabItem { Label(L("tab.settings"), systemImage: "gearshape.fill") }
        }
        .tint(Theme.brandStart)
        .id(localization.language)
        .environment(localization)
        .environment(\.locale, localization.localeForFormatting)
        .task {
            if PersistenceController.storeOpenFailed {
                showStoreError = true
            } else {
                // Erst Altdaten aus dem App-Group-Store übernehmen, dann die alten
                // Beispieldaten einmalig entfernen. Neue Installationen starten leer.
                StoreMigration.runIfNeeded(into: context)
                SeedData.removeLegacySeedIfNeeded(from: context)
            }
            WidgetSnapshotWriter.refresh(context: context)
        }
        .alert(L("store.error.title"), isPresented: $showStoreError) {
            Button(L("common.done"), role: .cancel) {}
        } message: {
            Text(L("store.error.message"))
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                WidgetSnapshotWriter.refresh(context: context)
            }
        }
        .onOpenURL { url in
            if let id = DeepLink.wordID(from: url) {
                deepLink = IdentifiableID(id: id)
                AchievementService.recordEvent(\.widgetUsed, context: context) // „Widget-Fan"
            } else if DeepLink.isReview(url) {
                showReview = true
            }
        }
        .sheet(item: $deepLink) { item in
            WordRevealSheet(wordID: item.id)
        }
        .sheet(isPresented: $showReview) {
            ReviewSessionView()
        }
    }
}

#Preview {
    RootView()
        .modelContainer(PersistenceController.preview)
}
