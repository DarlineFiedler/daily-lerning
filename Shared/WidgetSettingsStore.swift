import Foundation

enum WidgetSettingsKeys {
    static let interval = "widget.interval"
    static let showMeaning = "widget.showMeaning"
    static let showMeaningOnTap = "widget.showMeaningOnTap"
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

    static var showMeaningOnTap: Bool {
        get { d.bool(forKey: WidgetSettingsKeys.showMeaningOnTap) }
        set { d.set(newValue, forKey: WidgetSettingsKeys.showMeaningOnTap) }
    }

    static var current: WidgetSettings {
        WidgetSettings(
            intervalMinutes: intervalMinutes,
            showMeaning: showMeaning,
            showMeaningOnTap: showMeaningOnTap
        )
    }
}
