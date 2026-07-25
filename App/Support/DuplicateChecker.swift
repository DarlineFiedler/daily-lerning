import Foundation

/// Erkennt beim Anlegen/Bearbeiten einer Vokabel, ob das eingegebene Wort bereits existiert.
/// Rein funktional (keine UI, kein SwiftData-Context nötig) und damit direkt testbar. Wird
/// von [[VocabEditView]] genutzt; der Vergleich ist – analog zur Suche in `SearchView` –
/// case-/diakritika-insensitiv, aber als **exakter** Wortabgleich (nicht Teilstring).
enum DuplicateChecker {

    /// Ein gefundenes Duplikat, gestaffelt nach Relevanz für die Warn-UI.
    enum Match: Equatable {
        /// Treffer in der aktuell gewählten Zielgruppe – deutliche Warnung.
        case sameGroup(Vocab)
        /// Treffer nur in einer anderen Gruppe – dezenter Hinweis (kann gewollt sein).
        case otherGroup(Vocab)
    }

    /// Erste bestehende Vokabel mit gleichem Wort (getrimmt, case-/diakritika-insensitiv),
    /// `excluding` (die gerade bearbeitete) ausgenommen. Ein Treffer in `group` hat Vorrang
    /// und wird als `.sameGroup` gemeldet, sonst als `.otherGroup`. Leeres/whitespace-Wort
    /// liefert `nil`.
    static func firstDuplicate(of word: String,
                               in group: VocabGroup?,
                               among vocabs: [Vocab],
                               excluding: Vocab? = nil) -> Match? {
        let key = normalize(word)
        guard !key.isEmpty else { return nil }

        var otherGroupMatch: Vocab?
        for candidate in vocabs {
            if let excluding, candidate === excluding { continue }
            guard normalize(candidate.word) == key else { continue }
            if let group, candidate.group === group {
                return .sameGroup(candidate)
            }
            if otherGroupMatch == nil { otherGroupMatch = candidate }
        }
        return otherGroupMatch.map(Match.otherGroup)
    }

    /// Normalisiert ein Wort für den Dubletten-Vergleich: Leerraum getrimmt sowie
    /// Groß-/Kleinschreibung und Diakritika gefaltet.
    private static func normalize(_ word: String) -> String {
        word
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }
}
