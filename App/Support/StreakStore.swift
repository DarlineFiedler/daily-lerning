import Foundation

enum StreakKeys {
    static let current = "streak.current"
    static let longest = "streak.longest"
    static let lastActiveDay = "streak.lastActiveDay" // Start des letzten aktiven Kalendertags
}

/// Tages-Streak (aufeinanderfolgende Kalendertage mit mindestens einer geübten
/// Vokabel). Persistiert im geteilten App-Group-`UserDefaults`, analog zu
/// `WidgetSettingsStore`.
enum StreakStore {
    private static var d: UserDefaults { AppGroup.defaults }

    static var current: Int { d.integer(forKey: StreakKeys.current) }
    static var longest: Int { d.integer(forKey: StreakKeys.longest) }

    /// Start des zuletzt aktiven Tages, oder `nil` wenn noch nie aktiv.
    static var lastActiveDay: Date? {
        let t = d.double(forKey: StreakKeys.lastActiveDay)
        return t == 0 ? nil : Date(timeIntervalSince1970: t)
    }

    /// Verbucht Aktivität für „heute". Idempotent pro Kalendertag: mehrfacher Aufruf
    /// am selben Tag ändert nichts. Gestern → +1, Lücke → Neustart bei 1.
    /// - Returns: der aktuelle Streak nach dem Update.
    @discardableResult
    static func registerActivity(on date: Date = .now, calendar: Calendar = .current) -> Int {
        let today = calendar.startOfDay(for: date)
        let next = nextStreak(lastActiveDay: lastActiveDay, current: current, today: date, calendar: calendar)
        d.set(next, forKey: StreakKeys.current)
        d.set(today.timeIntervalSince1970, forKey: StreakKeys.lastActiveDay)
        d.set(max(longest, next), forKey: StreakKeys.longest)
        return next
    }

    /// Aktueller Streak, aber 0, wenn der letzte aktive Tag weder heute noch gestern
    /// war (der Streak ist dann „abgelaufen"). Für die Anzeige.
    static func displayStreak(asOf date: Date = .now, calendar: Calendar = .current) -> Int {
        isStreakAlive(lastActiveDay: lastActiveDay, today: date, calendar: calendar) ? current : 0
    }

    // MARK: - Reine Logik (testbar, ohne Persistenz)

    /// Streak-Wert nach einem Aktivitäts-Tag. Selber Tag → unverändert, Vortag → +1,
    /// Lücke oder erster Tag → 1.
    static func nextStreak(lastActiveDay: Date?, current: Int, today: Date, calendar: Calendar = .current) -> Int {
        guard let last = lastActiveDay else { return 1 }
        let lastDay = calendar.startOfDay(for: last)
        let t = calendar.startOfDay(for: today)
        if lastDay == t { return max(current, 1) }
        let yesterday = calendar.date(byAdding: .day, value: -1, to: t)
        return lastDay == yesterday ? current + 1 : 1
    }

    /// Ist der Streak „lebendig" (letzter aktiver Tag heute oder gestern)?
    static func isStreakAlive(lastActiveDay: Date?, today: Date, calendar: Calendar = .current) -> Bool {
        guard let last = lastActiveDay else { return false }
        let lastDay = calendar.startOfDay(for: last)
        let t = calendar.startOfDay(for: today)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: t)
        return lastDay == t || lastDay == yesterday
    }
}
