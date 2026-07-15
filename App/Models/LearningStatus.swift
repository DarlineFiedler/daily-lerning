import SwiftUI

/// Lernstatus einer Vokabel – vier Stufen, automatisch aus dem „Geschafft-Counter“
/// berechnet oder manuell gesetzt.
enum LearningStatus: Int, Codable, CaseIterable, Identifiable {
    case new = 0            // Neu – noch nie in einem Lernvorgang bearbeitet
    case learning = 1       // Am Lernen
    case almostLearned = 2  // Fast gelernt
    case learned = 3        // Gelernt / „Kann ich“

    var id: Int { rawValue }

    /// Ab dieser Streak aufeinanderfolgender richtiger Antworten gilt eine Vokabel als gelernt.
    static let masteredThreshold = 5

    /// Berechnet den Status aus dem Counter und ob die Vokabel schon geübt wurde.
    static func computed(counter: Int, practiced: Bool) -> LearningStatus {
        guard practiced else { return .new }
        if counter >= masteredThreshold { return .learned }
        if counter >= 3 { return .almostLearned }
        return .learning
    }

    /// Localization-Key (siehe Localizable.xcstrings).
    var titleKey: String {
        switch self {
        case .new: return "status.new"
        case .learning: return "status.learning"
        case .almostLearned: return "status.almostLearned"
        case .learned: return "status.learned"
        }
    }

    var color: Color {
        switch self {
        case .new: return Color(hex: "#94A3B8")          // grau
        case .learning: return Color(hex: "#F59E0B")     // orange
        case .almostLearned: return Color(hex: "#3B82F6") // blau
        case .learned: return Color(hex: "#22C55E")      // grün
        }
    }

    var systemImage: String {
        switch self {
        case .new: return "circle"
        case .learning: return "circle.lefthalf.filled"
        case .almostLearned: return "circle.bottomhalf.filled"
        case .learned: return "checkmark.circle.fill"
        }
    }
}
