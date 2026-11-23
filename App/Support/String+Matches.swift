import Foundation

extension String {
    /// Groß-/Kleinschreibung- und diakritika-unempfindlicher Teilstring-Vergleich.
    /// Grundlage für die Textsuche/-filterung (Wortliste, Suche): `"café".matches("CAFE")`
    /// ist `true`. Vorher doppelt als private `String`-Extension in `WordListView`/`SearchView`.
    func matches(_ term: String) -> Bool {
        range(of: term, options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }
}
