import SwiftUI
import SwiftData

/// Wurzel-View mit den fünf Haupt-Tabs. Wird bei Sprachwechsel komplett neu
/// aufgebaut (`.id(localization.language)`), damit alle Texte aktualisiert werden.
struct RootView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase

    @State private var localization = LocalizationManager.shared
    @State private var deepLink: IdentifiableID?
    @State private var showReview = false

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
            SeedData.insertIfEmpty(into: context)
            WidgetSnapshotWriter.refresh(context: context)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                WidgetSnapshotWriter.refresh(context: context)
            }
        }
        .onOpenURL { url in
            if let id = DeepLink.wordID(from: url) {
                deepLink = IdentifiableID(id: id)
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
