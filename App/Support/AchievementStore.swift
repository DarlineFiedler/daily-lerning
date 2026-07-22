import Foundation

enum AchievementKeys {
    static let unlockedIDs = "achievements.unlockedIDs"
    static let unlockDates = "achievements.unlockDates" // [id: timeIntervalSince1970]
    static let progress = "achievements.progress.v2" // JSON-kodierter AchievementProgress
    // Legacy-Skalar-Keys – nur noch für die einmalige Migration alter Installationen.
    static let modesUsed = "achievements.modesUsed"
    static let weekdays = "achievements.weekdays"
    static let sessions = "achievements.sessions"
    static let perfectRounds = "achievements.perfectRounds"
    static let nightOwl = "achievements.nightOwl"
    static let earlyBird = "achievements.earlyBird"
}

/// Persistiert den Achievement-Fortschritt und die freigeschalteten Badges im
/// geteilten App-Group-`UserDefaults`, analog zu `StreakStore`. Die eigentliche
/// Logik (Sammeln, Auswerten) steckt in `AchievementProgress` / `AchievementEvaluator`
/// – dieser Store kümmert sich nur ums Lesen/Schreiben.
enum AchievementStore {
    private static var d: UserDefaults { AppGroup.defaults }

    // MARK: - Gesammelter Fortschritt

    static var progress: AchievementProgress {
        get {
            // Aktueller Zustand liegt als JSON vor; sonst einmalig aus den Legacy-Keys migrieren.
            if let data = d.data(forKey: AchievementKeys.progress),
               let decoded = try? JSONDecoder().decode(AchievementProgress.self, from: data) {
                return decoded
            }
            return legacyProgress()
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            d.set(data, forKey: AchievementKeys.progress)
        }
    }

    /// Baut den Fortschritt aus den alten Skalar-Keys (Installationen vor der JSON-Ablage).
    private static func legacyProgress() -> AchievementProgress {
        AchievementProgress(
            modesUsed: Set(d.stringArray(forKey: AchievementKeys.modesUsed) ?? []),
            weekdays: Set((d.array(forKey: AchievementKeys.weekdays) as? [Int]) ?? []),
            sessionsCompleted: d.integer(forKey: AchievementKeys.sessions),
            perfectRounds: d.integer(forKey: AchievementKeys.perfectRounds),
            nightOwl: d.bool(forKey: AchievementKeys.nightOwl),
            earlyBird: d.bool(forKey: AchievementKeys.earlyBird)
        )
    }

    // MARK: - Freigeschaltete Badges

    static var unlockedIDs: Set<String> {
        Set(d.stringArray(forKey: AchievementKeys.unlockedIDs) ?? [])
    }

    /// Zeitpunkt der Freischaltung eines Badges (für die Übersicht), oder `nil`.
    static func unlockDate(for id: String) -> Date? {
        guard let dates = d.dictionary(forKey: AchievementKeys.unlockDates) as? [String: Double],
              let t = dates[id] else { return nil }
        return Date(timeIntervalSince1970: t)
    }

    /// Merkt neu freigeschaltete Badges samt Zeitstempel. Idempotent: bereits
    /// bekannte IDs behalten ihren ursprünglichen Freischalt-Zeitpunkt.
    static func markUnlocked(_ achievements: [Achievement], on date: Date = .now) {
        guard !achievements.isEmpty else { return }
        var ids = unlockedIDs
        var dates = (d.dictionary(forKey: AchievementKeys.unlockDates) as? [String: Double]) ?? [:]
        for a in achievements where dates[a.id] == nil {
            ids.insert(a.id)
            dates[a.id] = date.timeIntervalSince1970
        }
        d.set(Array(ids), forKey: AchievementKeys.unlockedIDs)
        d.set(dates, forKey: AchievementKeys.unlockDates)
    }
}
