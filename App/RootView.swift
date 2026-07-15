import SwiftUI
import SwiftData

/// Wurzel-View mit den vier Haupt-Tabs. Wird bei Sprachwechsel komplett neu
/// aufgebaut (`.id(localization.language)`), damit alle Texte aktualisiert werden.
struct RootView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase

    @State private var localization = LocalizationManager.shared
    @State private var deepLink: IdentifiableID?

    var body: some View {
        TabView {
            GroupListView()
                .tabItem { Label(L("tab.groups"), systemImage: "rectangle.stack") }

            SearchView()
                .tabItem { Label(L("tab.search"), systemImage: "magnifyingglass") }

            StatisticsView()
                .tabItem { Label(L("tab.stats"), systemImage: "chart.bar") }

            SettingsView()
                .tabItem { Label(L("tab.settings"), systemImage: "gearshape") }
        }
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
            }
        }
        .sheet(item: $deepLink) { item in
            WordRevealSheet(wordID: item.id)
        }
    }
}

#Preview {
    RootView()
        .modelContainer(PersistenceController.preview)
}
