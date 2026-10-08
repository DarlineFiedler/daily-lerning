import SwiftUI

/// Barrierefreiheits-Helfer für die Lern-Modi (Issue #120): koreanischer
/// Sprachkontext für VoiceOver und abgeleiteter Status einer Antwortoption.

extension AttributedString {
    /// Markiert Text als Koreanisch, damit VoiceOver Hangul korrekt ausspricht
    /// (statt ihn nach Systemsprache zu lesen). Rein für Barrierefreiheit – die
    /// sichtbare Darstellung bleibt unverändert.
    static func korean(_ string: String) -> AttributedString {
        var attributed = AttributedString(string)
        attributed.languageIdentifier = "ko-KR"
        return attributed
    }
}

/// Barrierefreiheits-Status einer Antwortoption nach der Wahl – steuert, was
/// VoiceOver als Value/Trait meldet. Rein aus dem Zustand abgeleitet (testbar),
/// parallel zur sichtbaren Tönung in [[ChoiceOptionsView]].
enum ChoiceOptionState: Equatable {
    /// Noch nicht beantwortet.
    case unanswered
    /// Die richtige Lösung (nach der Antwort hervorgehoben).
    case correct
    /// Selbst gewählt, aber falsch.
    case chosenWrong
    /// Übrige, nicht gewählte Optionen nach der Antwort.
    case other

    static func resolve(answered: Bool, isRight: Bool, isChosen: Bool) -> ChoiceOptionState {
        guard answered else { return .unanswered }
        if isRight { return .correct }
        if isChosen { return .chosenWrong }
        return .other
    }
}
