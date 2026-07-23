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

    /// Freischalt-Bedingung – eine zählbare Schwelle (mit Fortschrittsbalken),
    /// ein einfaches Ja/Nein-Flag oder das Meta-Ziel „alle anderen Badges".
    enum Requirement: Equatable {
        case count(KeyPath<AchievementMetrics, Int>, Int)
        case flag(KeyPath<AchievementMetrics, Bool>)
        /// 100 %: alle übrigen (nicht-Meta-)Badges sind freigeschaltet. Wird aus
        /// `unlockedBadges`/`totalBadges` in den Metriken abgeleitet.
        case meta
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
        case .meta: return metrics.totalBadges > 0 && metrics.unlockedBadges >= metrics.totalBadges
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
        case .meta:
            guard metrics.totalBadges > 0 else { return 0 }
            return min(1, Double(metrics.unlockedBadges) / Double(metrics.totalBadges))
        }
    }

    /// „x / y" für zählbare Ziele (auch das Meta-Ziel) – für Flags gibt es nichts
    /// zu zählen (`nil`).
    func progressText(_ metrics: AchievementMetrics) -> String? {
        switch requirement {
        case let .count(keyPath, target):
            return "\(min(metrics[keyPath: keyPath], target)) / \(target)"
        case .meta:
            return "\(min(metrics.unlockedBadges, metrics.totalBadges)) / \(metrics.totalBadges)"
        case .flag:
            return nil
        }
    }
}

/// Momentaufnahme aller Kennzahlen, aus denen sich Badges ableiten. Wird aus den
/// Vokabeldaten (gelernte/gesamte Wörter, längster Streak, gemeisterte Gruppe) plus
/// dem gemerkten Lernverhalten (`AchievementProgress`) zusammengesetzt.
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
    // Verhaltens-/Kalender-Flags (aus dem gesammelten Fortschritt).
    var afterWork = false
    var weekend = false
    var usedListening = false
    var comeback = false
    var selfCorrection = false
    var allModesOneDay = false
    var doublePack = false
    var ghostHour = false
    var fridayThe13th = false
    var newYearsEve = false
    var serienComeback = false
    var hangulDay = false
    var fullMoon = false
    var sprachmix = false
    // Ereignis-Flags aus der App-Nutzung (außerhalb der Übungsrunde).
    var searchUsed = false
    var languageChanged = false
    var widgetUsed = false
    var groupCreated = false
    // Vokabel-/Gruppen-abhängige Flags.
    var schnapszahl = false
    var groupMastered = false
    var allGroupsMastered = false
    var everUsedJoker = false
    // Zählbare Serien/Vielfalt.
    var distinctSeasons = 0
    var sameModeDayStreak = 0
    var nightDayStreak = 0
    var oneWordDayStreak = 0
    var flawlessRoundStreak = 0
    var comebackCount = 0
    // Meta-Abschluss: freigeschaltete vs. gesamte (nicht-Meta-)Badges.
    var unlockedBadges = 0
    var totalBadges = 0

    static func from(progress: AchievementProgress,
                     learnedWords: Int,
                     totalWords: Int,
                     longestStreak: Int,
                     groupMastered: Bool = false,
                     allGroupsMastered: Bool = false,
                     everUsedJoker: Bool = false,
                     unlockedIDs: Set<String> = [],
                     catalog: [Achievement] = AchievementCatalog.all) -> AchievementMetrics {
        // Für das Meta-Badge zählen alle Badges außer dem Meta-Badge selbst.
        let nonMeta = catalog.filter { $0.requirement != .meta }
        return AchievementMetrics(
            learnedWords: learnedWords,
            totalWords: totalWords,
            longestStreak: longestStreak,
            distinctModes: progress.modesUsed.count,
            distinctWeekdays: progress.weekdays.count,
            sessionsCompleted: progress.sessionsCompleted,
            perfectRounds: progress.perfectRounds,
            nightOwl: progress.nightOwl,
            earlyBird: progress.earlyBird,
            afterWork: progress.afterWork,
            weekend: progress.weekend,
            usedListening: progress.modesUsed.contains(PracticeMode.listening.rawValue),
            comeback: progress.comeback,
            selfCorrection: progress.selfCorrection,
            allModesOneDay: progress.allModesOneDay,
            doublePack: progress.doublePack,
            ghostHour: progress.ghostHour,
            fridayThe13th: progress.fridayThe13th,
            newYearsEve: progress.newYearsEve,
            serienComeback: progress.serienComeback,
            hangulDay: progress.hangulDay,
            fullMoon: progress.fullMoon,
            sprachmix: progress.sprachmix,
            searchUsed: progress.searchUsed,
            languageChanged: progress.languageChanged,
            widgetUsed: progress.widgetUsed,
            groupCreated: progress.groupCreated,
            // „Schnapszahl": exakt 111 oder 222 gelernte Wörter (Easter Egg).
            schnapszahl: learnedWords == 111 || learnedWords == 222,
            groupMastered: groupMastered,
            allGroupsMastered: allGroupsMastered,
            everUsedJoker: everUsedJoker,
            distinctSeasons: progress.seasons.count,
            sameModeDayStreak: progress.sameMode.best,
            nightDayStreak: progress.nightNights.best,
            oneWordDayStreak: progress.oneWordDays.best,
            flawlessRoundStreak: progress.flawlessRun.best,
            comebackCount: progress.comebackCount,
            unlockedBadges: nonMeta.filter { unlockedIDs.contains($0.id) }.count,
            totalBadges: nonMeta.count
        )
    }
}

/// Serie aufeinanderfolgender *Kalendertage*, an denen eine Bedingung erfüllt war
/// (z.B. Nächte nach Mitternacht). Mehrfach am selben Tag ist idempotent, eine Lücke
/// setzt die laufende Serie zurück; `best` merkt sich das je erreichte Maximum.
struct DayRun: Equatable, Codable {
    var lastDay: Date?
    var run = 0
    var best = 0

    mutating func note(day: Date, calendar: Calendar) {
        let d = calendar.startOfDay(for: day)
        guard let last = lastDay else {
            run = 1
            lastDay = d
            best = Swift.max(best, run)
            return
        }
        if calendar.isDate(last, inSameDayAs: d) { return } // heute schon gezählt
        let gap = calendar.dateComponents([.day], from: last, to: d).day ?? 0
        run = gap == 1 ? run + 1 : 1
        lastDay = d
        best = Swift.max(best, run)
    }
}

/// Serie aufeinanderfolgender *Runden*, in denen eine Bedingung erfüllt war
/// (z.B. fehlerfrei). Ein Fehlschlag setzt zurück; `best` hält das Maximum.
struct RoundRun: Equatable, Codable {
    var run = 0
    var best = 0

    mutating func note(success: Bool) {
        run = success ? run + 1 : 0
        best = Swift.max(best, run)
    }
}

/// Aus dem Lernverhalten gesammelter Fortschritt, der sich NICHT direkt aus den
/// Vokabeldaten ableiten lässt (welche Modi genutzt, an welchen Wochentagen/Uhrzeiten
/// geübt, Serien …). Reine Wertlogik – die Persistenz übernimmt `AchievementStore`.
/// `Codable`, weil der Zustand als JSON in den geteilten Defaults liegt.
struct AchievementProgress: Equatable, Codable {
    var modesUsed: Set<String> = [] // PracticeMode.rawValue
    var weekdays: Set<Int> = [] // Calendar-Wochentag 1…7
    var sessionsCompleted = 0
    var perfectRounds = 0
    var nightOwl = false
    var earlyBird = false

    // Einfache, einmal erreichbare Flags.
    var afterWork = false // 18–19:59 Uhr geübt
    var weekend = false // Sa/So geübt
    var comeback = false // nach ≥3 Tagen Pause wieder geübt
    var selfCorrection = false // zuvor falsches Wort später richtig
    var ghostHour = false // Runde exakt um 00:00 beendet
    var fridayThe13th = false // an einem Freitag, dem 13.
    var newYearsEve = false // am 31.12.
    var allModesOneDay = false // alle 4 Modi an einem Kalendertag
    var doublePack = false // ≥2 Runden am selben Tag
    var serienComeback = false // nach gerissenem Streak einen längeren aufgebaut
    var hangulDay = false // am 9. Oktober (한글날) geübt
    var fullMoon = false // an einem Vollmond-Datum geübt
    var sprachmix = false // Wörter aus ≥3 Gruppen an einem Tag geübt

    // Zähler für mehrfache Comebacks (nach je ≥3 Tagen Pause wieder geübt).
    var comebackCount = 0

    // Ereignis-Flags aus der App-Nutzung (außerhalb der Übungsrunde gesetzt).
    var searchUsed = false // die Suche einmal benutzt
    var languageChanged = false // Sprache in den Einstellungen gewechselt
    var widgetUsed = false // über das Lock-Screen-Widget geöffnet
    var groupCreated = false // eine eigene Vokabelgruppe angelegt

    // Meteorologische Jahreszeiten (0=Winter,1=Frühling,2=Sommer,3=Herbst).
    var seasons: Set<Int> = []

    // Serien.
    var sameMode = DayRun() // gleicher (einziger) Modus an Folgetagen
    var sameModeMode: String? // Modus, der die aktuelle sameMode-Serie trägt
    var nightNights = DayRun() // Folge-Nächte nach Mitternacht
    var oneWordDays = DayRun() // Folgetage mit genau 1 neuem Wort
    var flawlessRun = RoundRun() // aufeinanderfolgende fehlerfreie Runden

    // Tagespuffer (wird beim Tageswechsel zurückgesetzt).
    var currentDay: Date?
    var modesToday: Set<String> = []
    var sessionsToday = 0
    var newWordsToday = 0
    var groupsToday: Set<String> = [] // an diesem Tag geübte Vokabelgruppen (für „Sprachmix")
    // Rollback-Puffer für „genau 1 Wort/Tag", falls später ein 2. Wort dazukommt.
    var oneWordCountedToday = false
    var oneWordPreRun = 0
    var oneWordPreLastDay: Date?

    // Comeback-/Serien-Comeback-Zustand.
    var lastSessionDay: Date?
    var lastStreakValue = 0
    var hadBreak = false
    var preBreakStreak = 0

    /// Meteorologische Jahreszeit (Nordhalbkugel) für einen Monat 1…12.
    static func season(forMonth month: Int) -> Int {
        switch month {
        case 12, 1, 2: return 0 // Winter
        case 3, 4, 5: return 1 // Frühling
        case 6, 7, 8: return 2 // Sommer
        default: return 3 // Herbst
        }
    }

    /// Verbucht eine beendete Übungsrunde und aktualisiert alle abgeleiteten Serien/Flags.
    /// - Parameters:
    ///   - modes: die in der Runde genutzten Modi.
    ///   - date: Zeitpunkt des Rundenendes (Uhrzeit/Datum bestimmen viele Flags).
    ///   - isPerfect: fehlerfrei mit genug Wörtern (siehe `PracticeSession`).
    ///   - isFlawless: fehlerfrei, unabhängig von der Wortanzahl (für die Fehlerfrei-Serie).
    ///   - selfCorrected: ein zuvor falsch beantwortetes Wort wurde diesmal richtig.
    ///   - newlyLearned: Anzahl in dieser Runde neu auf „gelernt" gestiegener Wörter.
    ///   - currentStreak: aktueller Tages-Streak (für das Serien-Comeback).
    mutating func recordSession(modes: Set<PracticeMode>,
                                date: Date,
                                isPerfect: Bool,
                                isFlawless: Bool = false,
                                selfCorrected: Bool = false,
                                newlyLearned: Int = 0,
                                currentStreak: Int = 0,
                                groups: Set<String> = [],
                                calendar: Calendar = .current) {
        let modeRaws = Set(modes.map(\.rawValue))
        let day = calendar.startOfDay(for: date)
        let comps = calendar.dateComponents([.weekday, .hour, .minute, .year, .month, .day], from: date)
        let weekday = comps.weekday ?? 1
        let hour = comps.hour ?? 0
        let minute = comps.minute ?? 0
        let year = comps.year ?? 0
        let month = comps.month ?? 1
        let dayOfMonth = comps.day ?? 1

        if selfCorrected { selfCorrection = true }
        recordBasics(modeRaws: modeRaws, weekday: weekday, hour: hour, month: month, isPerfect: isPerfect)
        recordSpecialDates(weekday: weekday, hour: hour, minute: minute, year: year, month: month, dayOfMonth: dayOfMonth)
        recordSeries(modeRaws: modeRaws, day: day, hour: hour, isFlawless: isFlawless, calendar: calendar)
        recordDayBuffer(modeRaws: modeRaws, day: day, newlyLearned: newlyLearned, groups: groups, calendar: calendar)
        recordComeback(day: day, currentStreak: currentStreak, calendar: calendar)
    }

    // MARK: - Teil-Schritte von recordSession (getrennt für geringe Komplexität)

    /// Zähler + einfache Tages-/Uhrzeit-Flags (Basis, Feierabend, Wochenende, Jahreszeit).
    private mutating func recordBasics(modeRaws: Set<String>, weekday: Int, hour: Int, month: Int, isPerfect: Bool) {
        modesUsed.formUnion(modeRaws)
        weekdays.insert(weekday)
        sessionsCompleted += 1
        if isPerfect { perfectRounds += 1 }
        if hour < 5 { nightOwl = true } // 0–4:59 Uhr → Nachteule
        if (5 ..< 8).contains(hour) { earlyBird = true } // 5–7:59 Uhr → Früher Vogel
        if (18 ..< 20).contains(hour) { afterWork = true } // Feierabend
        if weekday == 1 || weekday == 7 { weekend = true } // 1=So, 7=Sa
        seasons.insert(Self.season(forMonth: month))
    }

    /// Seltene Kalender-Flags (Geisterstunde, Freitag der 13., Silvester, 한글날, Vollmond).
    private mutating func recordSpecialDates(weekday: Int, hour: Int, minute: Int, year: Int, month: Int, dayOfMonth: Int) {
        if hour == 0, minute == 0 { ghostHour = true } // exakt Mitternacht
        if weekday == 6, dayOfMonth == 13 { fridayThe13th = true } // 6=Fr
        if month == 12, dayOfMonth == 31 { newYearsEve = true }
        if month == 10, dayOfMonth == 9 { hangulDay = true } // 한글날, Tag des Hangeul
        if FullMoonDates.contains(year: year, month: month, day: dayOfMonth) { fullMoon = true }
    }

    /// Runden-/Tages-Serien: fehlerfrei, Nächte nach Mitternacht, gleicher Modus an Folgetagen.
    private mutating func recordSeries(modeRaws: Set<String>, day: Date, hour: Int, isFlawless: Bool, calendar: Calendar) {
        flawlessRun.note(success: isFlawless)
        if hour < 5 { nightNights.note(day: day, calendar: calendar) }
        // Gleicher (einziger) Modus an Folgetagen – nur die erste Ein-Modus-Runde des Tages.
        guard modeRaws.count == 1, let onlyMode = modeRaws.first else { return }
        if sameMode.lastDay.map({ calendar.isDate($0, inSameDayAs: day) }) ?? false { return }
        let gap = sameMode.lastDay.map { calendar.dateComponents([.day], from: $0, to: day).day ?? 0 }
        if gap == 1, sameModeMode == onlyMode {
            sameMode.run += 1
        } else {
            sameMode.run = 1
            sameModeMode = onlyMode
        }
        sameMode.lastDay = day
        sameMode.best = Swift.max(sameMode.best, sameMode.run)
    }

    /// Tagespuffer: Doppelpack, alle Modi an einem Tag, „genau 1 Wort am Tag", Sprachmix.
    private mutating func recordDayBuffer(modeRaws: Set<String>, day: Date, newlyLearned: Int, groups: Set<String>, calendar: Calendar) {
        if currentDay.map({ !calendar.isDate($0, inSameDayAs: day) }) ?? true {
            currentDay = day
            modesToday = []
            sessionsToday = 0
            newWordsToday = 0
            groupsToday = []
            oneWordCountedToday = false
        }
        modesToday.formUnion(modeRaws)
        sessionsToday += 1
        newWordsToday += newlyLearned
        groupsToday.formUnion(groups)
        if modesToday.count >= PracticeMode.allCases.count { allModesOneDay = true }
        if sessionsToday >= 2 { doublePack = true }
        if groupsToday.count >= 3 { sprachmix = true } // Wörter aus ≥3 Gruppen an einem Tag
        // „Ein Wort am Tag": Tag zählt, solange genau 1 neues Wort. Kommt am selben Tag
        // ein zweites dazu, wird die optimistisch gezählte Serie zurückgerollt; `best`
        // bleibt bewusst stehen (augenzwinkerndes Easter-Egg).
        if newWordsToday == 1, !oneWordCountedToday {
            oneWordPreRun = oneWordDays.run
            oneWordPreLastDay = oneWordDays.lastDay
            oneWordDays.note(day: day, calendar: calendar)
            oneWordCountedToday = true
        } else if newWordsToday >= 2, oneWordCountedToday {
            oneWordDays.run = oneWordPreRun
            oneWordDays.lastDay = oneWordPreLastDay
            oneWordCountedToday = false
        }
    }

    /// Comeback nach ≥3 Tagen Pause + Serien-Comeback nach gerissenem Streak.
    private mutating func recordComeback(day: Date, currentStreak: Int, calendar: Calendar) {
        if let last = lastSessionDay {
            let gap = calendar.dateComponents([.day], from: calendar.startOfDay(for: last), to: day).day ?? 0
            if gap >= 3 {
                comeback = true
                comebackCount += 1 // jedes erneute Comeback zählt (für „Comeback-König")
            }
        }
        lastSessionDay = day
        if currentStreak < lastStreakValue {
            hadBreak = true
            preBreakStreak = lastStreakValue
        }
        if hadBreak, preBreakStreak >= 2, currentStreak > preBreakStreak {
            serienComeback = true
        }
        lastStreakValue = currentStreak
    }
}

/// Feste Liste von Vollmond-Daten (lokales Kalenderdatum) für das verspielte
/// „Mondschein"-Badge. Rein kosmetisch – Näherungswerte reichen völlig.
enum FullMoonDates {
    /// Vollmonde 2025–2027 als (Jahr, Monat, Tag).
    static let all: Set<[Int]> = [
        // 2025
        [2025, 1, 13], [2025, 2, 12], [2025, 3, 14], [2025, 4, 13], [2025, 5, 12], [2025, 6, 11],
        [2025, 7, 10], [2025, 8, 9], [2025, 9, 7], [2025, 10, 7], [2025, 11, 5], [2025, 12, 4],
        // 2026
        [2026, 1, 3], [2026, 2, 1], [2026, 3, 3], [2026, 4, 2], [2026, 5, 1], [2026, 5, 31],
        [2026, 6, 29], [2026, 7, 29], [2026, 8, 28], [2026, 9, 26], [2026, 10, 26], [2026, 11, 24], [2026, 12, 24],
        // 2027
        [2027, 1, 22], [2027, 2, 20], [2027, 3, 22], [2027, 4, 20], [2027, 5, 20], [2027, 6, 19],
        [2027, 7, 18], [2027, 8, 17], [2027, 9, 15], [2027, 10, 15], [2027, 11, 14], [2027, 12, 13],
    ]

    static func contains(year: Int, month: Int, day: Int) -> Bool {
        all.contains([year, month, day])
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
        Achievement(id: "earlyBird", category: .fun, emoji: "🐦", requirement: .flag(\.earlyBird)),

        // --- Erweiterung: Quick Wins ---
        Achievement(id: "comeback", category: .streak, emoji: "🔙", requirement: .flag(\.comeback)),
        Achievement(id: "afterWork", category: .fun, emoji: "🌆", requirement: .flag(\.afterWork)),
        Achievement(id: "weekend", category: .variety, emoji: "🎉", requirement: .flag(\.weekend)),
        Achievement(id: "listening", category: .variety, emoji: "🎧", requirement: .flag(\.usedListening)),
        Achievement(id: "selfCorrect", category: .sessions, emoji: "🔁", requirement: .flag(\.selfCorrection)),

        // --- Erweiterung: Mittelschwer ---
        Achievement(id: "doublePack", category: .sessions, emoji: "✌️", requirement: .flag(\.doublePack)),
        Achievement(id: "allModesDay", category: .variety, emoji: "🎯", requirement: .flag(\.allModesOneDay)),
        Achievement(id: "seasons", category: .variety, emoji: "🍂", requirement: .count(\.distinctSeasons, 4)),
        Achievement(id: "sameModeStreak", category: .variety, emoji: "🔂", requirement: .count(\.sameModeDayStreak, 5)),
        Achievement(id: "flawlessStreak", category: .sessions, emoji: "🎖️", requirement: .count(\.flawlessRoundStreak, 3)),

        // --- Erweiterung: Prestige ---
        Achievement(id: "serienComeback", category: .streak, emoji: "🎢", requirement: .flag(\.serienComeback)),
        Achievement(id: "learned1000", category: .learned, emoji: "🏛️", requirement: .count(\.learnedWords, 1000)),
        Achievement(id: "streak365", category: .streak, emoji: "🎆", requirement: .count(\.longestStreak, 365)),
        Achievement(id: "perfektionist", category: .fun, emoji: "🌟", requirement: .count(\.perfectRounds, 10)),
        Achievement(id: "nightStreak", category: .fun, emoji: "🌃", requirement: .count(\.nightDayStreak, 3)),

        // --- Erweiterung: Spaßig ---
        Achievement(id: "ghostHour", category: .fun, emoji: "👻", requirement: .flag(\.ghostHour)),
        Achievement(id: "friday13", category: .fun, emoji: "🃏", requirement: .flag(\.fridayThe13th)),
        Achievement(id: "newYearsEve", category: .fun, emoji: "🎇", requirement: .flag(\.newYearsEve)),
        Achievement(id: "schnapszahl", category: .fun, emoji: "🔢", requirement: .flag(\.schnapszahl)),
        Achievement(id: "oneWordDay", category: .fun, emoji: "🐢", requirement: .count(\.oneWordDayStreak, 7)),

        // --- Erweiterung: Themen ---
        Achievement(id: "themenMeister", category: .learned, emoji: "🗂️", requirement: .flag(\.groupMastered)),

        // --- Erweiterung: Meilensteine & App-Nutzung ---
        Achievement(id: "learned2000", category: .learned, emoji: "🏔️", requirement: .count(\.learnedWords, 2000)),
        Achievement(id: "firstGroup", category: .learned, emoji: "🗃️", requirement: .flag(\.groupCreated)),
        Achievement(id: "alleGruppen", category: .learned, emoji: "🗂️👑", requirement: .flag(\.allGroupsMastered)),
        Achievement(id: "comebackKoenig", category: .streak, emoji: "🔂", requirement: .count(\.comebackCount, 3)),
        Achievement(id: "retter", category: .streak, emoji: "🧊", requirement: .flag(\.everUsedJoker)),
        Achievement(id: "sprachmix", category: .variety, emoji: "🌍", requirement: .flag(\.sprachmix)),
        Achievement(id: "firstSearch", category: .fun, emoji: "🔍", requirement: .flag(\.searchUsed)),
        Achievement(id: "settingsExplorer", category: .fun, emoji: "⚙️", requirement: .flag(\.languageChanged)),
        Achievement(id: "widgetActive", category: .fun, emoji: "📱", requirement: .flag(\.widgetUsed)),
        Achievement(id: "hangulDay", category: .fun, emoji: "🎊", requirement: .flag(\.hangulDay)),
        Achievement(id: "mondSchein", category: .fun, emoji: "🌕", requirement: .flag(\.fullMoon)),

        // --- Meta: 100 % ---
        Achievement(id: "vollendung", category: .fun, emoji: "🏆✨", requirement: .meta)
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
