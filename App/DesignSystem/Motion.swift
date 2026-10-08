import SwiftUI

/// Zentrale Reduce-Motion-Hilfe (Issue #120): respektiert die Systemeinstellung
/// „Bewegung reduzieren". Bei aktivem Reduce-Motion wird `nil` zurückgegeben →
/// SwiftUI vollzieht den Zustandswechsel ohne Animation (sofortiger Endzustand),
/// statt Spring-/Scale-/Transition-Effekte abzuspielen. Nutzer:innen mit
/// Bewegungsempfindlichkeit bekommen so die Feier-Elemente ruhig statt bewegt.
enum Motion {
    /// Liefert `animation`, oder `nil` wenn Reduce-Motion aktiv ist. `nil` an
    /// `withAnimation(_:)` bzw. `.animation(_:value:)` bedeutet: kein Animieren.
    static func animation(_ animation: Animation, reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : animation
    }
}
