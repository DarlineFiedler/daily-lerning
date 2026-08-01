import Foundation

/// Fehlertolerantes Decoding für `AchievementProgress`.
///
/// Der Fortschritt wird als JSON in `AchievementStore.progress` persistiert und über die
/// Zeit um neue Felder erweitert (z.B. `flawlessToday`). Das **synthetisierte** `Codable`
/// wirft bei einem fehlenden Schlüssel jedoch `keyNotFound` – auch wenn die Property einen
/// Default hat (Defaults werden vom generierten Decoder nicht berücksichtigt). Über den
/// `try?`-Fallback in `AchievementStore.progress` würde ein solcher Fehler den gesamten
/// gespeicherten Fortschritt auf `legacyProgress()` (≈ leer) zurücksetzen – nach jedem
/// Update, das ein Feld ergänzt.
///
/// Dieser handgeschriebene Initializer decodiert jedes Feld über `decodeIfPresent` und
/// fällt bei Abwesenheit auf den Property-Default zurück. Damit überstehen bestehende
/// Speicherstände jede künftige Feld-Erweiterung verlustfrei. `encode(to:)` bleibt
/// synthetisiert (nutzt das explizite `CodingKeys` im Typ); der Initializer liegt bewusst
/// in einer Extension, damit der memberwise- und der parameterlose Initializer erhalten bleiben.
extension AchievementProgress {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init()

        modesUsed = try c.decodeIfPresent(Set<String>.self, forKey: .modesUsed) ?? modesUsed
        weekdays = try c.decodeIfPresent(Set<Int>.self, forKey: .weekdays) ?? weekdays
        sessionsCompleted = try c.decodeIfPresent(Int.self, forKey: .sessionsCompleted) ?? sessionsCompleted
        perfectRounds = try c.decodeIfPresent(Int.self, forKey: .perfectRounds) ?? perfectRounds
        nightOwl = try c.decodeIfPresent(Bool.self, forKey: .nightOwl) ?? nightOwl
        earlyBird = try c.decodeIfPresent(Bool.self, forKey: .earlyBird) ?? earlyBird

        afterWork = try c.decodeIfPresent(Bool.self, forKey: .afterWork) ?? afterWork
        weekend = try c.decodeIfPresent(Bool.self, forKey: .weekend) ?? weekend
        comeback = try c.decodeIfPresent(Bool.self, forKey: .comeback) ?? comeback
        selfCorrection = try c.decodeIfPresent(Bool.self, forKey: .selfCorrection) ?? selfCorrection
        ghostHour = try c.decodeIfPresent(Bool.self, forKey: .ghostHour) ?? ghostHour
        fridayThe13th = try c.decodeIfPresent(Bool.self, forKey: .fridayThe13th) ?? fridayThe13th
        newYearsEve = try c.decodeIfPresent(Bool.self, forKey: .newYearsEve) ?? newYearsEve
        allModesOneDay = try c.decodeIfPresent(Bool.self, forKey: .allModesOneDay) ?? allModesOneDay
        doublePack = try c.decodeIfPresent(Bool.self, forKey: .doublePack) ?? doublePack
        serienComeback = try c.decodeIfPresent(Bool.self, forKey: .serienComeback) ?? serienComeback
        hangulDay = try c.decodeIfPresent(Bool.self, forKey: .hangulDay) ?? hangulDay
        fullMoon = try c.decodeIfPresent(Bool.self, forKey: .fullMoon) ?? fullMoon
        sprachmix = try c.decodeIfPresent(Bool.self, forKey: .sprachmix) ?? sprachmix
        bossDefeated = try c.decodeIfPresent(Bool.self, forKey: .bossDefeated) ?? bossDefeated

        comebackCount = try c.decodeIfPresent(Int.self, forKey: .comebackCount) ?? comebackCount

        searchUsed = try c.decodeIfPresent(Bool.self, forKey: .searchUsed) ?? searchUsed
        languageChanged = try c.decodeIfPresent(Bool.self, forKey: .languageChanged) ?? languageChanged
        widgetUsed = try c.decodeIfPresent(Bool.self, forKey: .widgetUsed) ?? widgetUsed
        groupCreated = try c.decodeIfPresent(Bool.self, forKey: .groupCreated) ?? groupCreated
        weeklyGoalReached = try c.decodeIfPresent(Bool.self, forKey: .weeklyGoalReached) ?? weeklyGoalReached

        seasons = try c.decodeIfPresent(Set<Int>.self, forKey: .seasons) ?? seasons

        sameMode = try c.decodeIfPresent(DayRun.self, forKey: .sameMode) ?? sameMode
        sameModeMode = try c.decodeIfPresent(String.self, forKey: .sameModeMode)
        nightNights = try c.decodeIfPresent(DayRun.self, forKey: .nightNights) ?? nightNights
        oneWordDays = try c.decodeIfPresent(DayRun.self, forKey: .oneWordDays) ?? oneWordDays
        flawlessRun = try c.decodeIfPresent(RoundRun.self, forKey: .flawlessRun) ?? flawlessRun

        currentDay = try c.decodeIfPresent(Date.self, forKey: .currentDay)
        modesToday = try c.decodeIfPresent(Set<String>.self, forKey: .modesToday) ?? modesToday
        sessionsToday = try c.decodeIfPresent(Int.self, forKey: .sessionsToday) ?? sessionsToday
        newWordsToday = try c.decodeIfPresent(Int.self, forKey: .newWordsToday) ?? newWordsToday
        groupsToday = try c.decodeIfPresent(Set<String>.self, forKey: .groupsToday) ?? groupsToday
        flawlessToday = try c.decodeIfPresent(Bool.self, forKey: .flawlessToday) ?? flawlessToday
        oneWordCountedToday = try c.decodeIfPresent(Bool.self, forKey: .oneWordCountedToday) ?? oneWordCountedToday
        oneWordPreRun = try c.decodeIfPresent(Int.self, forKey: .oneWordPreRun) ?? oneWordPreRun
        oneWordPreLastDay = try c.decodeIfPresent(Date.self, forKey: .oneWordPreLastDay)

        lastSessionDay = try c.decodeIfPresent(Date.self, forKey: .lastSessionDay)
        lastStreakValue = try c.decodeIfPresent(Int.self, forKey: .lastStreakValue) ?? lastStreakValue
        hadBreak = try c.decodeIfPresent(Bool.self, forKey: .hadBreak) ?? hadBreak
        preBreakStreak = try c.decodeIfPresent(Int.self, forKey: .preBreakStreak) ?? preBreakStreak
    }
}
