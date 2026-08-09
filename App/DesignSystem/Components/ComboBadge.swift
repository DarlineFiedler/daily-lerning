import SwiftUI

/// Flüchtiges „🔥 ×N Kombo"-Badge, das während einer Übungsrunde bei aufeinander-
/// folgenden richtigen Antworten erscheint (Issue #90). Rein präsentativ – der Zähler
/// selbst lebt transient in `PracticeSession`. Ab einem Meilenstein (siehe
/// `PracticeSession.isComboMilestone`) tritt es kräftiger auf.
///
/// Blendet sich unterhalb der Sichtbarkeitsschwelle komplett aus (`EmptyView`), damit es
/// den Lernfluss nicht stört; der Aufrufer platziert es als nicht-interaktives Overlay.
struct ComboBadge: View {
    let combo: Int

    private var isVisible: Bool { combo >= PracticeSession.comboBadgeMin }
    private var isMilestone: Bool { PracticeSession.isComboMilestone(combo) }

    var body: some View {
        if isVisible {
            Label {
                Text(L("practice.combo", combo))
                    .font(.appSubheadline.weight(.bold))
                    .contentTransition(.numericText())
            } icon: {
                Text("🔥")
            }
            .foregroundStyle(.white)
            .padding(.horizontal, Theme.Spacing.m)
            .padding(.vertical, Theme.Spacing.s)
            .background(Theme.brandGradient, in: Capsule())
            .shadow(color: Theme.brandEnd.opacity(0.4), radius: isMilestone ? 14 : 8, y: 4)
            .scaleEffect(isMilestone ? 1.15 : 1)
            // Pro Kombo-Stand ein frischer Auftritt → jede Antwort „poppt" das Badge.
            .id(combo)
            .transition(.scale(scale: 0.5).combined(with: .opacity))
            .animation(.spring(response: 0.35, dampingFraction: 0.55), value: combo)
        }
    }
}
