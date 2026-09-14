import SwiftUI

/// Die drei Ziele der v3-Navigation.
enum GardenTab: Hashable {
    case garden
    case me
}

/// Individuelle Tabbar im Papier-Look: zwei seitliche Tabs (Garten · Ich) und ein
/// zentraler, runder **Üben-FAB**, der die Anzahl fälliger Wörter zeigt und leicht
/// nach unten übersteht (Screen 1a).
struct GardenTabBar: View {
    @Binding var selection: GardenTab
    let dueCount: Int
    let onPractice: () -> Void

    var body: some View {
        HStack(alignment: .bottom) {
            tab(.garden, emoji: "🌿", title: L("tab.garden"))
            Spacer()
            practiceFAB
            Spacer()
            tab(.me, emoji: "✦", title: L("tab.me"))
        }
        .padding(.horizontal, 30)
        .padding(.top, 10)
        .padding(.bottom, 6)
        .background(
            Theme.paper
                .overlay(Rectangle().fill(Theme.hairline).frame(height: 1), alignment: .top)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private func tab(_ tab: GardenTab, emoji: String, title: String) -> some View {
        let active = selection == tab
        return Button {
            selection = tab
        } label: {
            VStack(spacing: 3) {
                Text(emoji).font(.system(size: 20))
                Text(title)
                    .font(.appMono(10))
                    .tracking(0.5)
            }
            .foregroundStyle(active ? Theme.ink : Theme.inkMuted)
            .frame(width: 64)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(active ? [.isSelected, .isButton] : .isButton)
    }

    private var practiceFAB: some View {
        Button(action: onPractice) {
            VStack(spacing: 1) {
                Text(L("tab.practice"))
                    .font(.appDisplay(15))
                if dueCount > 0 {
                    Text(L("practice.fab.due", dueCount))
                        .font(.appMono(9))
                        .opacity(0.85)
                }
            }
            .foregroundStyle(Color(hex: "#FBF5EA"))
            .frame(width: 66, height: 66)
            .background(Theme.vermillion, in: Circle())
            .buttonHardShadow(Theme.vermillionDark, y: 5)
            .offset(y: -4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(L("tab.practice")), \(dueCount > 0 ? L("practice.fab.due", dueCount) : "")")
    }
}
