import ActivityKit
import Foundation

/// Geteilte Live-Activity-Definition für eine laufende Lernsession. Liegt in `Shared/`,
/// damit App (startet/aktualisiert/beendet) und Widget-Extension (rendert die UI)
/// denselben Typ sehen.
struct PracticeActivityAttributes: ActivityAttributes {
    /// Dynamischer Zustand, der sich während der Session ändert.
    struct ContentState: Codable, Hashable {
        var total: Int
        var position: Int
        var correct: Int
        var wrong: Int

        /// Fortschritt 0…1 (reine Berechnung, ohne ActivityKit – daher unit-testbar).
        var progress: Double {
            guard total > 0 else { return 0 }
            return min(1, max(0, Double(position) / Double(total)))
        }
    }

    /// Statische Attribute (bleiben über die Lebensdauer der Activity konstant).
    /// Aktuell ohne Felder – der Titel wird lokalisiert in der Widget-UI gesetzt.
    var kind: String = "practice"
}
