import Foundation

/// Eine tagesaktuelle Mini-Challenge – kleine, täglich wechselnde Kleinaufgabe auf dem
/// Home-Screen (getrennt vom dauerhaften Achievement-System und vom persönlichen Ziel).
///
/// Der Fortschritt wird bewusst aus den **bereits vorhandenen Tagespuffern** von
/// `AchievementProgress` abgeleitet (`modesToday`, `sessionsToday`, `newWordsToday`,
/// `groupsToday`, `flawlessToday`), die beim Tageswechsel automatisch zurückgesetzt werden.
struct DailyChallenge: Identifiable, Equatable {
    /// Welche Tages-Kennzahl die Challenge misst.
    enum Metric: Equatable {
        case modes // verschiedene Übungsmodi am Tag
        case sessions // abgeschlossene Übungsrunden am Tag
        case newWords // neu auf „gelernt" gestiegene Wörter am Tag
        case groups // verschiedene geübte Vokabelgruppen am Tag
        case flawless // eine fehlerfreie Runde am Tag geschafft
    }

    /// Stabiler Bezeichner – dient zugleich als Stamm des Lokalisierungs-Keys
    /// (`dailyChallenge.<id>.title`).
    let id: String
    let emoji: String
    let metric: Metric
    let target: Int

    var titleKey: String { "dailyChallenge.\(id).title" }

    /// Heutiger Fortschritt gegen die Challenge, abgeleitet aus dem Tagespuffer.
    /// Der Puffer wird nur *lazy* beim nächsten Session-Write auf den neuen Tag
    /// zurückgesetzt – deshalb zählen die Werte nur, wenn `currentDay` heute ist.
    func done(from progress: AchievementProgress, now: Date = .now, calendar: Calendar = .current) -> Int {
        let today = calendar.startOfDay(for: now)
        guard let day = progress.currentDay, calendar.isDate(day, inSameDayAs: today) else { return 0 }
        switch metric {
        case .modes: return progress.modesToday.count
        case .sessions: return progress.sessionsToday
        case .newWords: return progress.newWordsToday
        case .groups: return progress.groupsToday.count
        case .flawless: return progress.flawlessToday ? 1 : 0
        }
    }

    /// Ist die heutige Challenge erfüllt?
    func isSatisfied(from progress: AchievementProgress, now: Date = .now, calendar: Calendar = .current) -> Bool {
        done(from: progress, now: now, calendar: calendar) >= target
    }
}

/// Momentaufnahme der heutigen Challenge inkl. Fortschritt – für die Home-Karte.
struct DailyChallengeSnapshot: Equatable {
    let challenge: DailyChallenge
    let done: Int
    var target: Int { challenge.target }
    var satisfied: Bool { done >= challenge.target }
    var fraction: Double { challenge.target > 0 ? min(1, Double(done) / Double(challenge.target)) : 0 }
}

/// Katalog der verfügbaren Challenge-Vorlagen. Alle Ziele sind bewusst so gewählt,
/// dass sie an einem einzelnen Tag erreichbar bleiben.
enum DailyChallengeCatalog {
    static let all: [DailyChallenge] = [
        DailyChallenge(id: "modes", emoji: "🎨", metric: .modes, target: 3),
        DailyChallenge(id: "sessions", emoji: "🔁", metric: .sessions, target: 2),
        DailyChallenge(id: "newWords", emoji: "🌱", metric: .newWords, target: 3),
        DailyChallenge(id: "groups", emoji: "🌍", metric: .groups, target: 2),
        DailyChallenge(id: "flawless", emoji: "✨", metric: .flawless, target: 1)
    ]

    /// Fester Basis-Seed für die Auswahl. Kompilierzeit-Konstante (keine Persistenz nötig):
    /// die Auswahl folgt rein aus `(Tages-Index, Seed)` und ist damit stabil und testbar.
    static let seed: UInt64 = 0x0DA1_1C4A_11E6_5EED

    /// Wählt die Challenge für einen gegebenen Tages-Index. Innerhalb eines Zyklus von
    /// `count` Tagen kommt jede Challenge genau einmal dran (seed-gemischte Permutation),
    /// danach neu gemischt – deterministisch pro Kalendertag.
    static func forDay(index: Int, seed: UInt64 = seed) -> DailyChallenge {
        guard !all.isEmpty else { fatalError("DailyChallengeCatalog darf nicht leer sein") }
        let i = WidgetRotation.wordIndex(forSlot: index, wordCount: all.count, seed: seed)
        return all[i]
    }
}

/// Tages-Index = Anzahl lokaler Kalendertage seit einem festen Referenztag – identisch
/// zum Muster in `WordOfDay`. Bewusst NICHT `ordinality(of:.day,in:.era)` (rechnet in GMT
/// und verschiebt den Tageswechsel je nach Zeitzone weg von lokaler Mitternacht).
enum DailyChallengeCalendar {
    static func todayIndex(now: Date = .now, calendar: Calendar = .current) -> Int {
        let epoch = calendar.startOfDay(for: Date(timeIntervalSinceReferenceDate: 0))
        let today = calendar.startOfDay(for: now)
        return calendar.dateComponents([.day], from: epoch, to: today).day ?? 0
    }
}
