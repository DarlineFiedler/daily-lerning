import Foundation

/// Zentrale Konstanten für den Datenaustausch zwischen App und Widget-Extension.
enum AppGroup {
    /// Muss identisch mit den Einträgen in den .entitlements beider Targets sein.
    ///
    /// v3 „Hangul Garten" nutzt eine EIGENE App-Group, damit die neue App neben der
    /// alten DailyHangul-App installiert werden kann, ohne deren geteilte Daten
    /// (Widget-Snapshot, UserDefaults) zu überschreiben.
    static let identifier = "group.com.darlinefiedler.hangulgarten"

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
    /// Eigener Scheme für v3, damit Links eindeutig „Hangul Garten" öffnen und nicht
    /// die parallel installierte alte App.
    static let urlScheme = "hangulgarten"

    /// Gemeinsam genutzte, gecachte JSON-Coder für die UserDefaults-JSON-Stores
    /// (XP, Tages-Challenge, Ziel-Historie, Wochen-Log, Achievements). `JSONEncoder`/
    /// `JSONDecoder` sind die teuersten Foundation-Coder; vorher allozierte jeder
    /// `save`/`load` eine frische Instanz. Default-Konfiguration – Caching ändert die
    /// erzeugten Bytes nicht. Gleiches Muster wie der gecachte DateFormatter aus #143.
    /// Thread-sicher: `JSONEncoder`/`JSONDecoder` sind ab iOS 17 `Sendable` – die Instanzen
    /// werden auch nebenläufig genutzt (App, Widget-Timeline-Provider, App Intents, da
    /// `Shared/` in beide Targets kompiliert wird). Deshalb NIE zur Laufzeit umkonfigurieren
    /// (z.B. `dateEncodingStrategy`); wer andere Einstellungen braucht, nimmt eigene Coder.
    static let jsonEncoder = JSONEncoder()
    static let jsonDecoder = JSONDecoder()
}

extension UserDefaults {
    /// Dekodiert einen JSON-Wert unter `key`. Schlägt die Dekodierung fehl (korrupter Blob),
    /// wird der rohe Inhalt EINMALIG unter `<key>.corrupt` gesichert, BEVOR der Aufrufer auf
    /// seinen Default zurückfällt – sonst überschreibt der nächste `save()` die korrupten
    /// (evtl. per Hand rettbaren) Bytes unwiederbringlich. Gibt `nil` zurück, wenn kein Wert
    /// existiert oder die Dekodierung fehlschlägt.
    func decodeJSONOrPreserve<T: Decodable>(_ type: T.Type, forKey key: String,
                                            decoder: JSONDecoder = AppGroup.jsonDecoder) -> T? {
        guard let data = data(forKey: key) else { return nil }
        if let decoded = try? decoder.decode(type, from: data) { return decoded }
        // Erste Korruption gewinnt: eine schon vorhandene Sicherung nicht überschreiben.
        if object(forKey: key + ".corrupt") == nil {
            set(data, forKey: key + ".corrupt")
        }
        return nil
    }

    /// Kodiert `value` als JSON und schreibt es unter `key`. Bei einem Encode-Fehler
    /// passiert nichts (der alte Wert bleibt stehen) – identisch zum bisherigen
    /// `guard let data = try? …encode(…) else { return }` in den Stores, nur mit dem
    /// gecachten `AppGroup.jsonEncoder` statt einer frischen Instanz je Aufruf.
    func saveJSON<T: Encodable>(_ value: T, forKey key: String,
                                encoder: JSONEncoder = AppGroup.jsonEncoder) {
        guard let data = try? encoder.encode(value) else { return }
        set(data, forKey: key)
    }
}

/// `kind`-Identifikatoren der Home-Screen-Widgets. Geteilt zwischen Widget-Target
/// (Registrierung) und App (gezieltes Neuladen), damit die App genau EIN Widget
/// aktualisieren kann statt `reloadAllTimelines()` über alle Kinds zu feuern.
enum WidgetKind {
    static let vocab = "DailyHangulWidget"
    static let streak = "StreakWidget"
}
