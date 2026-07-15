import Foundation

/// Lernmodus.
enum PracticeMode: String, CaseIterable, Identifiable {
    case multipleChoice
    case review
    case writing

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .multipleChoice: return "practice.mode.multipleChoice"
        case .review: return "practice.mode.review"
        case .writing: return "practice.mode.writing"
        }
    }

    var systemImage: String {
        switch self {
        case .multipleChoice: return "list.bullet"
        case .review: return "rectangle.stack"
        case .writing: return "pencil"
        }
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

/// Konfiguration eines Lernvorgangs.
struct PracticeConfig {
    /// Leere Menge = alle Status.
    var statuses: Set<LearningStatus> = []
    var direction: PracticeDirection = .wordToMeaning
    /// Leere Menge = alle Modi (= Mix über alles).
    var modes: Set<PracticeMode> = []

    var resolvedModes: [PracticeMode] {
        modes.isEmpty ? PracticeMode.allCases : Array(modes)
    }
}
