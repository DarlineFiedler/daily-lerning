import Foundation

enum StreakKeys {
    static let current = "streak.current"
    static let longest = "streak.longest"
    static let lastActiveDay = "streak.lastActiveDay" // Start des letzten aktiven Kalendertags
    static let jokers = "streak.jokers" // aktuell verfügbare Streak-Freeze-Joker
    static let weekAnchor = "streak.weekAnchor" // Start der Woche, für die zuletzt Joker vergeben wurden
    static let jokerUses = "streak.jokerUses" // [Double] Zeitstempel der per Joker geretteten Tage
    static let activeDays = "streak.activeDays" // [Double] Zeitstempel aller Tage mit Aktivität (Kalender)
}

/// Reiner, testbarer Zustand der Tages-Streak inklusive Streak-Freeze-Jokern.
/// Enthält keine Persistenz – `StreakStore` lädt/speichert ihn.
struct StreakState: Equatable {
    var current: Int = 0
    var longest: Int = 0
    var lastActiveDay: Date?
    var jokers: Int = 0
    /// Start der Woche, für die zuletzt der Wochenjoker vergeben wurde.
    var weekAnchor: Date?
    /// Tage, die per Joker gerettet wurden (für die Einsatz-Historie).
    var jokerUses: [Date] = []
    /// Alle Tage (Tagesanfang) mit mindestens einer Aktivität – für den Kalender.
    var activeDays: [Date] = []

    /// Vergibt fällige Wochenjoker: 1 pro angebrochener Kalenderwoche seit
    /// `weekAnchor`, gedeckelt bei `max`. Idempotent innerhalb derselben Woche.
    /// Beim allerersten Aufruf gibt es sofort einen Startjoker.
    func grantingJokers(asOf date: Date, calendar: Calendar, max: Int) -> StreakState {
        var s = self
        let weekStart = calendar.startOfWeek(for: date)
        guard let anchor = weekAnchor else {
            s.jokers = Swift.min(max, s.jokers + 1)
            s.weekAnchor = weekStart
            return s
        }
        let weeks = calendar.dateComponents([.weekOfYear], from: anchor, to: weekStart).weekOfYear ?? 0
        if weeks > 0 {
            s.jokers = Swift.min(max, s.jokers + weeks)
            s.weekAnchor = weekStart
        }
        return s
    }

    /// Verbucht Aktivität an `date`. Vergibt zuerst fällige Joker, überbrückt dann
    /// verpasste Tage mit vorhandenen Jokern (statt die Streak zu resetten). Reicht
    /// der Joker-Vorrat nicht, startet die Streak neu bei 1. Idempotent pro Tag.
    func registeringActivity(on date: Date, calendar: Calendar, maxJokers: Int) -> StreakState {
        var s = grantingJokers(asOf: date, calendar: calendar, max: maxJokers)
        let today = calendar.startOfDay(for: date)
        if !s.activeDays.contains(today) { s.activeDays.append(today) }

        guard let last = s.lastActiveDay else {
            s.current = 1
            s.lastActiveDay = today
            s.longest = Swift.max(s.longest, 1)
            return s
        }

        let lastDay = calendar.startOfDay(for: last)
        let gap = calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0

        if gap <= 0 {
            // Selber Tag (oder Uhr zurückgestellt) → keine Änderung an der Streak.
            s.current = Swift.max(s.current, 1)
            return s
        }

        if gap == 1 {
            s.current += 1
        } else {
            let missed = gap - 1
            if s.jokers >= missed {
                s.jokers -= missed
                for offset in 1 ... missed {
                    if let saved = calendar.date(byAdding: .day, value: offset, to: lastDay) {
                        s.jokerUses.append(saved)
                    }
                }
                s.current += 1
            } else {
                s.current = 1
            }
        }

        s.lastActiveDay = today
        s.longest = Swift.max(s.longest, s.current)
        return s
    }

    /// Sichtbarer Streak: der aktuelle Wert, solange er lebt (heute/gestern aktiv)
    /// oder die entstandene Lücke noch mit vorhandenen Jokern rettbar ist; sonst 0.
    func displayStreak(asOf date: Date, calendar: Calendar, maxJokers: Int) -> Int {
        let s = grantingJokers(asOf: date, calendar: calendar, max: maxJokers)
        guard let last = s.lastActiveDay else { return 0 }
        let lastDay = calendar.startOfDay(for: last)
        let today = calendar.startOfDay(for: date)
        let gap = calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0
        if gap <= 1 { return s.current } // heute oder gestern aktiv
        let missed = gap - 1
        return s.jokers >= missed ? s.current : 0
    }
}

/// Tages-Streak (aufeinanderfolgende Kalendertage mit mindestens einer geübten
/// Vokabel) mit Streak-Freeze-Jokern. Persistiert im geteilten App-Group-
/// `UserDefaults`, analog zu `WidgetSettingsStore`.
enum StreakStore {
    private static var d: UserDefaults { AppGroup.defaults }

    /// Obergrenze für ansammelbare Joker – verhindert unbegrenztes Horten.
    static let maxJokers = 3

    // MARK: - Persistierter Zustand (lesend)

    static var current: Int { d.integer(forKey: StreakKeys.current) }
    static var longest: Int { d.integer(forKey: StreakKeys.longest) }

    /// Start des zuletzt aktiven Tages, oder `nil` wenn noch nie aktiv.
    static var lastActiveDay: Date? { date(forKey: StreakKeys.lastActiveDay) }

    /// Tage, die per Joker gerettet wurden (neueste zuletzt), für die Historie.
    static var jokerUses: [Date] {
        timestamps(forKey: StreakKeys.jokerUses)
    }

    /// Alle Tage mit Aktivität – für die Kalenderansicht.
    static var activeDays: [Date] {
        timestamps(forKey: StreakKeys.activeDays)
    }

    private static func timestamps(forKey key: String) -> [Date] {
        (d.array(forKey: key) as? [Double] ?? []).map { Date(timeIntervalSince1970: $0) }
    }

    // MARK: - Öffentliche API

    /// Verbucht Aktivität für „heute". Idempotent pro Kalendertag. Verpasste Tage
    /// werden – soweit Joker vorhanden – automatisch überbrückt.
    /// - Returns: der aktuelle Streak nach dem Update.
    @discardableResult
    static func registerActivity(on date: Date = .now, calendar: Calendar = .current) -> Int {
        let s = load().registeringActivity(on: date, calendar: calendar, maxJokers: maxJokers)
        save(s)
        return s.current
    }

    /// Vergibt fällige Wochenjoker und persistiert sie. Beim App-Start bzw. beim
    /// Anzeigen des Home-Screens aufrufen, damit der Joker-Stand aktuell ist.
    static func settle(on date: Date = .now, calendar: Calendar = .current) {
        save(load().grantingJokers(asOf: date, calendar: calendar, max: maxJokers))
    }

    /// Aktueller Streak, aber 0, wenn abgelaufen und nicht mehr per Joker rettbar.
    static func displayStreak(asOf date: Date = .now, calendar: Calendar = .current) -> Int {
        load().displayStreak(asOf: date, calendar: calendar, maxJokers: maxJokers)
    }

    /// Aktuell verfügbare Joker, inklusive noch nicht persistierter Wochenvergabe.
    static func availableJokers(asOf date: Date = .now, calendar: Calendar = .current) -> Int {
        load().grantingJokers(asOf: date, calendar: calendar, max: maxJokers).jokers
    }

    // MARK: - Laden / Speichern

    private static func load() -> StreakState {
        StreakState(
            current: current,
            longest: longest,
            lastActiveDay: date(forKey: StreakKeys.lastActiveDay),
            jokers: d.integer(forKey: StreakKeys.jokers),
            weekAnchor: date(forKey: StreakKeys.weekAnchor),
            jokerUses: jokerUses,
            activeDays: activeDays
        )
    }

    private static func save(_ s: StreakState) {
        d.set(s.current, forKey: StreakKeys.current)
        d.set(s.longest, forKey: StreakKeys.longest)
        d.set(s.jokers, forKey: StreakKeys.jokers)
        setDate(s.lastActiveDay, forKey: StreakKeys.lastActiveDay)
        setDate(s.weekAnchor, forKey: StreakKeys.weekAnchor)
        d.set(s.jokerUses.map(\.timeIntervalSince1970), forKey: StreakKeys.jokerUses)
        d.set(s.activeDays.map(\.timeIntervalSince1970), forKey: StreakKeys.activeDays)
    }

    private static func date(forKey key: String) -> Date? {
        let t = d.double(forKey: key)
        return t == 0 ? nil : Date(timeIntervalSince1970: t)
    }

    private static func setDate(_ value: Date?, forKey key: String) {
        if let value {
            d.set(value.timeIntervalSince1970, forKey: key)
        } else {
            d.removeObject(forKey: key)
        }
    }
}

extension Calendar {
    /// Start der Kalenderwoche, die `date` enthält (respektiert `firstWeekday`).
    func startOfWeek(for date: Date) -> Date {
        dateInterval(of: .weekOfYear, for: date)?.start ?? startOfDay(for: date)
    }
}
