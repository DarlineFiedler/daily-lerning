import SwiftData
import SwiftUI

/// **Screen 1j — „Ich"** (v3-Redesign, Phase-2-Grundgerüst).
/// Sammel-Tab für Profil und alle Nebenansichten, die es nicht mehr als eigene
/// System-Tabs gibt: Statistik, Sammlung, Suche, Übersetzer, Einstellungen.
/// Das reichere Profil (XP/Level, Sticker-Vorschau) folgt in Phase 4.
struct IchView: View {
    @AppStorage(XPKeys.state, store: AppGroup.defaults) private var xpStateData = Data()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    profileCard
                    section {
                        row(L("tab.stats"), emoji: "🌦️") { StatisticsView() }
                        row(L("ach.title"), emoji: "✦") { AchievementsView() }
                    }
                    section {
                        row(L("tab.groups"), emoji: "🪴") { GroupListView() }
                        row(L("tab.search"), emoji: "🔍") { SearchView() }
                        row(L("translator.title"), emoji: "🈯") { TranslatorView() }
                    }
                    section {
                        row(L("tab.settings"), emoji: "⚙️") { SettingsView() }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                // Platz für die schwebende Üben-FAB/Tab-Leiste am unteren Rand.
                .padding(.bottom, 88)
            }
            .paperBackground()
            .navigationTitle(L("tab.me"))
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var profileCard: some View {
        let level = XPStore.level(from: xpStateData)
        return HStack(spacing: 14) {
            Text("✦")
                .font(.appDisplay(26))
                .foregroundStyle(Theme.ocher)
                .frame(width: 52, height: 52)
                .background(Theme.ocher.opacity(0.14), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(L("home.level", level.level))
                    .font(.appTitle3)
                    .foregroundStyle(Theme.ink)
                Text(L(level.rankKey))
                    .font(.appMono(12))
                    .foregroundStyle(Theme.inkSecondary)
            }
            Spacer()
            Text("\(level.totalXP) XP")
                .font(.appMono(13))
                .foregroundStyle(Theme.vermillion)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .paperCard()
    }

    private func section<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 0) { content() }
            .paperCard(padding: 0)
    }

    private func row<Destination: View>(_ title: String, emoji: String,
                                        @ViewBuilder destination: @escaping () -> Destination) -> some View {
        NavigationLink { destination() } label: {
            HStack(spacing: 14) {
                Text(emoji).font(.system(size: 20)).frame(width: 26)
                Text(title)
                    .font(.appBody)
                    .foregroundStyle(Theme.ink)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.appCaption)
                    .foregroundStyle(Theme.inkMuted)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    IchView()
        .modelContainer(PersistenceController.preview)
}
