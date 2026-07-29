import Foundation
import SwiftData
import UserNotifications

enum BadgeKeys {
    static let enabled = "badge.enabled"
}

/// Setzt die Anzahl der heute noch offenen Wörter als Zahl-Badge auf das App-Icon.
/// Opt-in über `BadgeKeys.enabled`; nutzt die bereits von `NotificationScheduler`
/// angefragte `.badge`-Berechtigung. Aufzurufen, wann immer sich der Fälligkeitsstand
/// ändern kann (App-Start, Vordergrund, nach Session, nach Vokabel-Änderung).
@MainActor
enum BadgeUpdater {

    /// Berechnet die offene Wortzahl neu und aktualisiert das Badge.
    /// Ist das Feature deaktiviert, wird das Badge auf 0 gesetzt (entfernt).
    /// Wörter aus archivierten Gruppen zählen nicht als „offen" – die Gruppe ist
    /// pausiert und taucht auch sonst nicht mehr in den aktiven Flächen auf; daher
    /// wird bereits eine gefilterte, aktive Wortliste erwartet.
    static func refresh(activeVocabs: [Vocab]) {
        guard AppGroup.defaults.bool(forKey: BadgeKeys.enabled) else {
            setBadge(0)
            return
        }
        setBadge(DailyPlan.openWordCount(from: activeVocabs))
    }

    /// Convenience für Aufrufer ohne bereits geladene Wortliste (lädt sie selbst).
    /// Der Vokabel-Änderungspfad teilt sich den Fetch über [[AppContentRefresh]].
    static func refresh(context: ModelContext) {
        refresh(activeVocabs: AppContentRefresh.activeVocabs(context: context))
    }

    /// Setzt das App-Icon-Badge. Fehlt die Berechtigung, schlägt der Aufruf still
    /// fehl – das Badge bleibt dann einfach aus (kein Absturz/Fehlerzustand).
    static func setBadge(_ count: Int) {
        Task { try? await UNUserNotificationCenter.current().setBadgeCount(count) }
    }
}
