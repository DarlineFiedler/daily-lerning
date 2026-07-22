import Foundation

/// Lernmodus.
enum PracticeMode: String, CaseIterable, Identifiable {
    case multipleChoice
    case review
    case writing
    case listening

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .multipleChoice: return "practice.mode.multipleChoice"
        case .review: return "practice.mode.review"
        case .writing: return "practice.mode.writing"
        case .listening: return "practice.mode.listening"
        }
    }

    var systemImage: String {
        switch self {
        case .multipleChoice: return "list.bullet"
        case .review: return "rectangle.stack"
        case .writing: return "pencil"
        case .listening: return "ear.fill"
        }
    }

    /// Modi, die aktuell nutzbar sind. Der Hör-Modus fällt weg, wenn keine
    /// koreanische Stimme installiert ist (sonst gäbe es nichts zu hören).
    static var available: [PracticeMode] {
        available(hasVoice: SpeechService.isAvailable())
    }

    /// Wie `available`, aber mit injizierbarer Stimm-Verfügbarkeit – dadurch
    /// unabhängig von der Geräte-Konfiguration testbar.
    static func available(hasVoice: Bool) -> [PracticeMode] {
        allCases.filter { $0 != .listening || hasVoice }
    }
}

/// Abfragerichtung (wählbar; „mixed“ wird pro Wort zufällig aufgelöst).
enum PracticeDirection: String, CaseIterable, Identifiable {
    case wordToMeaning
    case meaningToWord
    case mixed

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .wordToMeaning: return "practice.direction.wordToMeaning"
        case .meaningToWord: return "practice.direction.meaningToWord"
        case .mixed: return "practice.direction.mixed"
        }
    }
}

/// Konkret aufgelöste Richtung für ein einzelnes Wort.
enum ResolvedDirection {
    case wordToMeaning
    case meaningToWord

    static func resolve(_ direction: PracticeDirection) -> ResolvedDirection {
        switch direction {
        case .wordToMeaning: return .wordToMeaning
        case .meaningToWord: return .meaningToWord
        case .mixed: return Bool.random() ? .wordToMeaning : .meaningToWord
        }
    }
}

/// Gemerkte Auswahl (Richtung + Modi) für den „Heute“-Lernvorgang. Kapselt das
/// Serialisieren/Parsen der `@AppStorage`-Werte, damit die Logik unabhängig von
/// der View getestet werden kann.
struct ReviewSelection: Equatable {
    var direction: PracticeDirection = .mixed
    /// Leere Menge = alle Modi (bisheriges Verhalten).
    var modes: Set<PracticeMode> = []
    /// Maximale Wortanzahl pro Durchgang. `nil` = alle heute fälligen Wörter.
    var wordLimit: Int?

    /// Rekonstruiert die Auswahl aus den gespeicherten rawValues. Eine ungültige
    /// Richtung fällt auf `.mixed` zurück; unbekannte oder nicht (mehr) verfügbare
    /// Modi – z.B. Hören ohne installierte koreanische Stimme – werden ausgefiltert.
    /// `wordLimitRaw` ≤ 0 bedeutet „alle Wörter" (`nil`), da `@AppStorage` kein
    /// optionales Int kennt.
    static func load(directionRaw: String, modesRaw: String, wordLimitRaw: Int = 0,
                     available: [PracticeMode] = PracticeMode.available) -> ReviewSelection {
        let direction = PracticeDirection(rawValue: directionRaw) ?? .mixed
        let stored = modesRaw.split(separator: ",").compactMap { PracticeMode(rawValue: String($0)) }
        return ReviewSelection(direction: direction,
                               modes: Set(stored).intersection(Set(available)),
                               wordLimit: wordLimitRaw > 0 ? wordLimitRaw : nil)
    }

    /// CSV der Modus-rawValues (stabil sortiert, damit derselbe Zustand denselben
    /// gespeicherten String ergibt) – leer = alle Modi.
    var modesRaw: String {
        modes.map(\.rawValue).sorted().joined(separator: ",")
    }

    /// Für `@AppStorage` speicherbare Wortanzahl – 0 = alle (`nil`).
    var wordLimitRaw: Int { wordLimit ?? 0 }
}

/// Konfiguration eines Lernvorgangs.
struct PracticeConfig {
    /// Leere Menge = alle Status.
    var statuses: Set<LearningStatus> = []
    var direction: PracticeDirection = .wordToMeaning
    /// Leere Menge = alle Modi (= Mix über alles).
    var modes: Set<PracticeMode> = []
    /// Maximale Wortanzahl pro Durchgang. `nil` = alle.
    var wordLimit: Int?

    var resolvedModes: [PracticeMode] {
        modes.isEmpty ? PracticeMode.available : Array(modes)
    }
}
