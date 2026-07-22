import Foundation

/// Ein freischaltbares Achievement / Badge. Rein datengetrieben: Titel und
/// Beschreibung kommen aus der Localization (`ach.<id>.title` / `ach.<id>.detail`),
/// die Freischalt-Bedingung steckt in `requirement` und wird gegen die aktuellen
/// `AchievementMetrics` geprüft. Bewusst ohne Persistenz/SwiftData – der Fortschritt
/// leitet sich aus Vokabeldaten (`AchievementMetrics`) plus dem in `AchievementStore`
/// gemerkten Lernverhalten ab, siehe [[dailyhangul-app-spec]].
struct Achievement: Identifiable, Equatable {
    /// Grobe Einordnung fürs Gruppieren in der Übersicht.
    enum Category: String, CaseIterable, Identifiable {
        case learned // Lernmenge
        case streak // Tage am Stück
        case sessions // absolvierte Runden
        case variety // Modus-/Wochentag-Vielfalt
        case fun // augenzwinkernde Sonder-Badges

        var id: String { rawValue }
        var titleKey: String { "ach.category.\(rawValue)" }
    }

    /// Freischalt-Bedingung – entweder eine zählbare Schwelle (mit Fortschrittsbalken)
    /// oder ein einfaches Ja/Nein-Flag.
    enum Requirement: Equatable {
        case count(KeyPath<AchievementMetrics, Int>, Int)
        case flag(KeyPath<AchievementMetrics, Bool>)
    }

    /// Stabile ID – zugleich Baustein der Localization-Keys. Nie ändern (sonst gilt
    /// ein bereits freigeschaltetes Badge als neu).
    let id: String
    let category: Category
    /// Emoji als Badge-Symbol (bewusst verspielt statt SF-Symbol).
    let emoji: String
    let requirement: Requirement

    var titleKey: String { "ach.\(id).title" }
    var detailKey: String { "ach.\(id).detail" }

    func isUnlocked(_ metrics: AchievementMetrics) -> Bool {
        switch requirement {
        case let .count(keyPath, target): return metrics[keyPath: keyPath] >= target
        case let .flag(keyPath): return metrics[keyPath: keyPath]
        }
    }

    /// Fortschritt in Richtung Freischaltung, 0…1 (Flags sind 0 oder 1).
    func progress(_ metrics: AchievementMetrics) -> Double {
        switch requirement {
        case let .count(keyPath, target):
            guard target > 0 else { return 1 }
            return min(1, Double(metrics[keyPath: keyPath]) / Double(target))
        case let .flag(keyPath):
            return metrics[keyPath: keyPath] ? 1 : 0
        }
    }

    /// „x / y" für zählbare Ziele – für Flags gibt es nichts zu zählen (`nil`).
    func progressText(_ metrics: AchievementMetrics) -> String? {
        guard case let .count(keyPath, target) = requirement else { return nil }
        return "\(min(metrics[keyPath: keyPath], target)) / \(target)"
    }
}

/// Momentaufnahme aller Kennzahlen, aus denen sich Badges ableiten. Wird aus den
/// Vokabeldaten (gelernte/gesamte Wörter, längster Streak) plus dem gemerkten
/// Lernverhalten (`AchievementProgress`) zusammengesetzt.
struct AchievementMetrics: Equatable {
    var learnedWords = 0
    var totalWords = 0
    var longestStreak = 0
    var distinctModes = 0
    var distinctWeekdays = 0
    var sessionsCompleted = 0
    var perfectRounds = 0
    var nightOwl = false
    var earlyBird = false

    static func from(progress: AchievementProgress, learnedWords: Int, totalWords: Int, longestStreak: Int) -> AchievementMetrics {
        AchievementMetrics(
            learnedWords: learnedWords,
            totalWords: totalWords,
            longestStreak: longestStreak,
            distinctModes: progress.modesUsed.count,
            distinctWeekdays: progress.weekdays.count,
            sessionsCompleted: progress.sessionsCompleted,
            perfectRounds: progress.perfectRounds,
            nightOwl: progress.nightOwl,
            earlyBird: progress.earlyBird
        )
    }
}

/// Aus dem Lernverhalten gesammelter Fortschritt, der sich NICHT direkt aus den
/// Vokabeldaten ableiten lässt (welche Modi genutzt, an welchen Wochentagen geübt,
/// wie viele Runden …). Reine Wertlogik – die Persistenz übernimmt `AchievementStore`.
struct AchievementProgress: Equatable {
    var modesUsed: Set<String> = [] // PracticeMode.rawValue
    var weekdays: Set<Int> = [] // Calendar-Wochentag 1…7
    var sessionsCompleted = 0
    var perfectRounds = 0
    var nightOwl = false
    var earlyBird = false

    /// Verbucht eine beendete Übungsrunde. `hour` ist die Stunde (0…23) des Rundenendes.
    mutating func recordSession(modes: Set<PracticeMode>, weekday: Int, hour: Int, isPerfect: Bool) {
        modesUsed.formUnion(modes.map(\.rawValue))
        weekdays.insert(weekday)
        sessionsCompleted += 1
        if isPerfect { perfectRounds += 1 }
        if hour < 5 { nightOwl = true } // 0–4:59 Uhr → Nachteule
        if (5 ..< 8).contains(hour) { earlyBird = true } // 5–7:59 Uhr → Früher Vogel
    }
}

/// Feste Erst-Version der Badge-Liste. Reihenfolge = Anzeigereihenfolge.
/// Milestones (Lernmenge, Streak, Runden, Vielfalt) plus ein paar augenzwinkernde.
enum AchievementCatalog {
    static let all: [Achievement] = [
        // Lernmenge
        Achievement(id: "learned1", category: .learned, emoji: "🌱", requirement: .count(\.learnedWords, 1)),
        Achievement(id: "learned10", category: .learned, emoji: "🔥", requirement: .count(\.learnedWords, 10)),
        Achievement(id: "learned50", category: .learned, emoji: "📚", requirement: .count(\.learnedWords, 50)),
        Achievement(id: "learned100", category: .learned, emoji: "💎", requirement: .count(\.learnedWords, 100)),
        Achievement(id: "learned250", category: .learned, emoji: "🧠", requirement: .count(\.learnedWords, 250)),
        Achievement(id: "learned500", category: .learned, emoji: "📖", requirement: .count(\.learnedWords, 500)),
        // Streak (längster je erreichter)
        Achievement(id: "streak3", category: .streak, emoji: "📆", requirement: .count(\.longestStreak, 3)),
        Achievement(id: "streak7", category: .streak, emoji: "🗓️", requirement: .count(\.longestStreak, 7)),
        Achievement(id: "streak30", category: .streak, emoji: "🏅", requirement: .count(\.longestStreak, 30)),
        Achievement(id: "streak100", category: .streak, emoji: "💯", requirement: .count(\.longestStreak, 100)),
        // Absolvierte Runden
        Achievement(id: "sessions1", category: .sessions, emoji: "🚀", requirement: .count(\.sessionsCompleted, 1)),
        Achievement(id: "sessions10", category: .sessions, emoji: "🐝", requirement: .count(\.sessionsCompleted, 10)),
        Achievement(id: "sessions50", category: .sessions, emoji: "🏆", requirement: .count(\.sessionsCompleted, 50)),
        // Vielfalt
        Achievement(id: "modes3", category: .variety, emoji: "🎨", requirement: .count(\.distinctModes, 3)),
        Achievement(id: "modesAll", category: .variety, emoji: "🎛️", requirement: .count(\.distinctModes, 4)),
        Achievement(id: "weekday5", category: .variety, emoji: "📅", requirement: .count(\.distinctWeekdays, 5)),
        Achievement(id: "weekday7", category: .variety, emoji: "🌈", requirement: .count(\.distinctWeekdays, 7)),
        // Augenzwinkernd
        Achievement(id: "perfect", category: .fun, emoji: "✨", requirement: .count(\.perfectRounds, 1)),
        Achievement(id: "nightOwl", category: .fun, emoji: "🦉", requirement: .flag(\.nightOwl)),
        Achievement(id: "earlyBird", category: .fun, emoji: "🐦", requirement: .flag(\.earlyBird))
    ]
}

/// Reine, testbare Auswertung: welche Badges sind nach den aktuellen Metriken neu
/// freigeschaltet (erfüllt, aber noch nicht in `alreadyUnlocked`)?
enum AchievementEvaluator {
    static func newlyUnlocked(metrics: AchievementMetrics,
                              alreadyUnlocked: Set<String>,
                              catalog: [Achievement] = AchievementCatalog.all) -> [Achievement] {
        catalog.filter { !alreadyUnlocked.contains($0.id) && $0.isUnlocked(metrics) }
    }
}
