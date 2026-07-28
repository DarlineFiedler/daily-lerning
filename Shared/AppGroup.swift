import Foundation

/// Zentrale Konstanten für den Datenaustausch zwischen App und Widget-Extension.
enum AppGroup {
    /// Muss identisch mit den Einträgen in den .entitlements beider Targets sein.
    static let identifier = "group.com.darlinefiedler.dailyhangul"

    /// Gemeinsamer UserDefaults-Container (Widget-Einstellungen).
    ///
    /// Bewusst eine **stabile** (einmalig erzeugte) Instanz statt einer berechneten
    /// Property: `@AppStorage` beobachtet Änderungen über genau das `UserDefaults`-Objekt,
    /// das ihm beim Anlegen übergeben wird. Würde hier bei jedem Zugriff eine neue
    /// `UserDefaults(suiteName:)`-Instanz zurückkommen, bekämen Views in anderen Tabs
    /// (z.B. das Ziel auf dem Home-Screen) Schreibvorgänge aus den Einstellungen nicht
    /// mit – die Änderung würde erst nach einem App-Neustart sichtbar.
    static let defaults = UserDefaults(suiteName: identifier) ?? .standard

    /// Gemeinsamer Datei-Container (JSON-Snapshot für das Widget).
    static var containerURL: URL {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: identifier)
            ?? URL.temporaryDirectory
    }

    /// Speicherort des Widget-Snapshots.
    static var snapshotURL: URL {
        containerURL.appendingPathComponent("widget_snapshot.json")
    }

    /// Custom URL-Scheme für Deep-Links aus dem Widget.
    static let urlScheme = "dailyhangul"
}

/// `kind`-Identifikatoren der Home-Screen-Widgets. Geteilt zwischen Widget-Target
/// (Registrierung) und App (gezieltes Neuladen), damit die App genau EIN Widget
/// aktualisieren kann statt `reloadAllTimelines()` über alle Kinds zu feuern.
enum WidgetKind {
    static let vocab = "DailyHangulWidget"
    static let streak = "StreakWidget"
}
