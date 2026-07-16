import SwiftUI

/// Lernstatus einer Vokabel – vier Stufen, automatisch aus dem „Geschafft-Counter“
/// berechnet oder manuell gesetzt.
enum LearningStatus: Int, Codable, CaseIterable, Identifiable {
    case new = 0            // Neu – noch nie in einem Lernvorgang bearbeitet
    case learning = 1       // Am Lernen
    case almostLearned = 2  // Fast gelernt
    case learned = 3        // Gelernt / „Kann ich“

    var id: Int { rawValue }

    /// Streak-Schwellen (aufeinanderfolgende richtige Antworten) je Stufe.
    /// Zentral definiert, damit `computed` und `setStatusManually` nicht auseinanderdriften.
    static let learningThreshold = 1
    static let almostLearnedThreshold = 3
    /// Ab dieser Streak gilt eine Vokabel als gelernt.
    static let masteredThreshold = 5

    /// Berechnet den Status aus dem Counter und ob die Vokabel schon geübt wurde.
    static func computed(counter: Int, practiced: Bool) -> LearningStatus {
        guard practiced else { return .new }
        if counter >= masteredThreshold { return .learned }
        if counter >= almostLearnedThreshold { return .almostLearned }
        return .learning
    }

    /// Localization-Key (siehe Localizable.strings in den *.lproj-Ordnern).
    var titleKey: String {
        switch self {
        case .new: return "status.new"
        case .learning: return "status.learning"
        case .almostLearned: return "status.almostLearned"
        case .learned: return "status.learned"
        }
    }

    /// Adaptive Status-Farben aus dem Design-System (Light/Dark), siehe `Theme`.
    var color: Color {
        switch self {
        case .new: return Theme.statusNew
        case .learning: return Theme.statusLearning
        case .almostLearned: return Theme.statusAlmostLearned
        case .learned: return Theme.statusLearned
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
