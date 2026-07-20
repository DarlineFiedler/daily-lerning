import Foundation

enum WidgetSettingsKeys {
    static let interval = "widget.interval"
    static let showMeaning = "widget.showMeaning"
    static let rotationSeed = "widget.rotationSeed"
    static let rotationAnchor = "widget.rotationAnchor"
}

/// Liest/schreibt die Widget-Einstellungen im geteilten App-Group-UserDefaults.
/// Wird vom Snapshot-Writer (App) und ggf. vom Widget genutzt.
enum WidgetSettingsStore {
    private static var d: UserDefaults { AppGroup.defaults }

    static var intervalMinutes: Int {
        get {
            let v = d.integer(forKey: WidgetSettingsKeys.interval)
            return v == 0 ? 30 : v
        }
        set { d.set(newValue, forKey: WidgetSettingsKeys.interval) }
    }

    static var showMeaning: Bool {
        get {
            d.object(forKey: WidgetSettingsKeys.showMeaning) == nil
                ? true
                : d.bool(forKey: WidgetSettingsKeys.showMeaning)
        }
        set { d.set(newValue, forKey: WidgetSettingsKeys.showMeaning) }
    }

    /// Fester Zufalls-Seed für die Widget-Reihenfolge. Wird einmalig erzeugt und
    /// danach stabil gehalten, damit die Rotation über App-Öffnungen hinweg gleich bleibt.
    static var rotationSeed: UInt64 {
        if d.object(forKey: WidgetSettingsKeys.rotationSeed) == nil {
            let seed = UInt64.random(in: UInt64.min ... UInt64.max)
            d.set(Int(bitPattern: UInt(seed)), forKey: WidgetSettingsKeys.rotationSeed)
            return seed
        }
        return UInt64(bitPattern: Int64(d.integer(forKey: WidgetSettingsKeys.rotationSeed)))
    }

    /// Fester Ankerzeitpunkt für die Slot-Zählung. Wird einmalig gesetzt und
    /// danach stabil gehalten.
    static var rotationAnchor: Date {
        let stored = d.double(forKey: WidgetSettingsKeys.rotationAnchor)
        if stored == 0 {
            let now = Date()
            d.set(now.timeIntervalSince1970, forKey: WidgetSettingsKeys.rotationAnchor)
            return now
        }
        return Date(timeIntervalSince1970: stored)
    }

    static var current: WidgetSettings {
        WidgetSettings(
            intervalMinutes: intervalMinutes,
            showMeaning: showMeaning,
            rotationAnchor: rotationAnchor,
            rotationSeed: rotationSeed
        )
    }
}
