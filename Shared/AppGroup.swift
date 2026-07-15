import Foundation

/// Zentrale Konstanten für den Datenaustausch zwischen App und Widget-Extension.
enum AppGroup {
    /// Muss identisch mit den Einträgen in den .entitlements beider Targets sein.
    static let identifier = "group.com.darlinefiedler.dailyhangul"

    /// Gemeinsamer UserDefaults-Container (Widget-Einstellungen).
    static var defaults: UserDefaults {
        UserDefaults(suiteName: identifier) ?? .standard
    }

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
