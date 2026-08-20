import Foundation

enum XPKeys {
    static let state = "xp.state"
}

/// Reiner, testbarer XP-Zustand: nur die gesammelten Gesamtpunkte. Level und Rang
/// werden daraus abgeleitet (`XPLevel`), nicht gespeichert. Persistenz übernimmt
/// `XPStore` – hier steckt nur die Wertlogik (Muster wie [[DailyChallengeState]]).
struct XPState: Codable, Equatable {
    var totalXP = 0

    /// Vergibt Punkte (nie negativ) und gibt den neuen Zustand zurück.
    func awarding(_ points: Int) -> XPState {
        var copy = self
        copy.totalXP = Swift.max(0, totalXP + Swift.max(0, points))
        return copy
    }

    /// Abgeleiteter Level-/Rang-Zustand zum aktuellen Punktestand.
    var level: XPLevel { XPLevel.forXP(totalXP) }
}

/// Abgeleiteter, anzeigefertiger Level-/Rang-Zustand zu einem XP-Punktestand.
/// Rein berechnet – kein persistenter Zustand. Level sind unbegrenzt, Ränge auf
/// `rankCount` gedeckelt (Rangwechsel alle `levelsPerRank` Level).
struct XPLevel: Equatable {
    /// 1-basiertes Level (Level 1 = 0 XP).
    let level: Int
    /// Rang-Index 0…`rankCount-1` – Baustein des Localization-Keys.
    let rankIndex: Int
    /// Gesamt-XP, aus dem dieser Zustand berechnet wurde.
    let totalXP: Int

    /// Anzahl der Rangstufen (lokalisiert `xp.rank.0` … `xp.rank.<rankCount-1>`).
    static let rankCount = 8
    /// Nach so vielen Leveln wechselt der Rang.
    static let levelsPerRank = 3

    /// Kumulierte XP, um `level` gerade zu erreichen. Dreieckskurve × 100:
    /// L1=0, L2=100, L3=300, L4=600, L5=1000 … – frühe Level kommen schnell,
    /// spätere kosten spürbar mehr.
    static func threshold(forLevel level: Int) -> Int {
        guard level > 1 else { return 0 }
        return 50 * (level - 1) * level
    }

    /// Ermittelt das Level zu einem XP-Stand (Inverse der Schwellenkurve). Closed-form
    /// als Startschätzung, danach eine kleine Korrekturschleife gegen FP-Rundung an
    /// den Grenzen.
    static func level(forXP xp: Int) -> Int {
        guard xp > 0 else { return 1 }
        var n = Int((1 + (1 + Double(xp) / 12.5).squareRoot()) / 2)
        n = Swift.max(1, n)
        while threshold(forLevel: n + 1) <= xp { n += 1 }
        while threshold(forLevel: n) > xp { n -= 1 }
        return Swift.max(1, n)
    }

    static func rankIndex(forLevel level: Int) -> Int {
        Swift.min((level - 1) / levelsPerRank, rankCount - 1)
    }

    static func forXP(_ xp: Int) -> XPLevel {
        let clamped = Swift.max(0, xp)
        let level = level(forXP: clamped)
        return XPLevel(level: level, rankIndex: rankIndex(forLevel: level), totalXP: clamped)
    }

    /// Localization-Key des Rangnamens.
    var rankKey: String { "xp.rank.\(rankIndex)" }
}

/// XP-Formel: wie viele Punkte eine richtig beantwortete Vokabel bringt. Basis plus
/// Bonus für die laufende Kombo (siehe [[PracticeSession]] `currentCombo`) und die
/// Schwierigkeit des Worts (neue/ungefestigte Wörter belohnen das Erarbeiten stärker).
enum XPRules {
    /// Grundpunkte je richtiger Antwort.
    static let base = 10
    /// Deckel für die in den Combo-Bonus einfließenden Kombo-Stufen.
    static let comboBonusCap = 10

    /// Bonus für die laufende Kombo: +2 je Kombo-Stufe ab der zweiten, gedeckelt.
    static func comboBonus(_ combo: Int) -> Int {
        Swift.min(Swift.max(combo - 1, 0), comboBonusCap) * 2
    }

    /// Schwierigkeits-Bonus nach Lernstatus **vor** der Antwort: neue/ungefestigte
    /// Wörter geben mehr, bereits gelernte am wenigsten.
    static func difficultyBonus(_ status: LearningStatus) -> Int {
        switch status {
        case .new: return 6
        case .learning: return 4
        case .almostLearned: return 2
        case .learned: return 0
        }
    }

    /// Gesamtpunkte für eine richtige Antwort.
    static func points(combo: Int, status: LearningStatus) -> Int {
        base + comboBonus(combo) + difficultyBonus(status)
    }
}

/// Ergebnis einer XP-Vergabe: die vergebenen Punkte plus der Level-/Rang-Zustand
/// davor und danach – erlaubt der UI, einen Levelaufstieg zu feiern.
struct XPAward: Equatable {
    let points: Int
    let before: XPLevel
    let after: XPLevel

    var didLevelUp: Bool { after.level > before.level }
}

/// Persistiert den XP-Gesamtstand in den geteilten App-Group-Defaults (JSON, analog
/// zu [[DailyChallengeStore]]). Level und Rang werden lesend aus dem Punktestand
/// abgeleitet. Rein additive Fortschrittsschicht – Streak/Achievements bleiben davon
/// unberührt.
enum XPStore {
    private static var d: UserDefaults { AppGroup.defaults }

    /// Gesamter XP-Stand.
    static var totalXP: Int { load().totalXP }

    /// Aktueller Level-/Rang-Zustand.
    static var level: XPLevel { load().level }

    /// Level-/Rang-Zustand aus bereits geladenen Rohdaten (z.B. `@AppStorage`), ohne
    /// erneuten UserDefaults-Zugriff – für den Dashboard-Hot-Path. Leere/ungültige
    /// Daten ergeben den Startzustand (Level 1), analog zu `load()`.
    static func level(from data: Data) -> XPLevel {
        let state = (try? JSONDecoder().decode(XPState.self, from: data)) ?? XPState()
        return state.level
    }

    /// Vergibt Punkte, persistiert den neuen Stand und meldet den Level-/Rang-Übergang.
    @discardableResult
    static func award(_ points: Int) -> XPAward {
        let state = load()
        let before = state.level
        let updated = state.awarding(points)
        save(updated)
        return XPAward(points: Swift.max(0, points), before: before, after: updated.level)
    }

    // MARK: - Persistenz

    private static func load() -> XPState {
        guard let data = d.data(forKey: XPKeys.state),
              let decoded = try? JSONDecoder().decode(XPState.self, from: data)
        else { return XPState() }
        return decoded
    }

    private static func save(_ state: XPState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        d.set(data, forKey: XPKeys.state)
    }
}
