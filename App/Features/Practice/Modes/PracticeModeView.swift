import SwiftUI

/// Wählt zur Übungsaufgabe die passende Modus-Ansicht. Gemeinsam genutzt von
/// Lernvorgang, Endgegner-Kampf und Prüfung – die Container liefern nur ihren
/// eigenen `onAnswer`-Handler.
struct PracticeModeView: View {
    let item: PracticeItem
    let onAnswer: (Bool) -> Void

    var body: some View {
        switch item.mode {
        case .multipleChoice:
            MultipleChoiceView(item: item, onAnswer: onAnswer)
        case .review:
            ReviewSwipeView(item: item, onAnswer: onAnswer)
        case .writing:
            WritingView(item: item, onAnswer: onAnswer)
        case .listening:
            ListeningView(item: item, onAnswer: onAnswer)
        case .cloze:
            ClozeView(item: item, onAnswer: onAnswer)
        }
    }
}
