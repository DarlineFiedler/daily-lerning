import Foundation

extension String {
    /// Groß-/Kleinschreibung- und diakritika-unempfindlicher Teilstring-Vergleich.
    /// Grundlage für die Textsuche/-filterung (Wortliste, Suche): `"café".containsLoosely("CAFE")`
    /// ist `true`. Ein leerer Begriff trifft IMMER (leeres Suchfeld ⇒ nichts ausfiltern) –
    /// anders als Foundations `range(of: "")`, das `nil` liefert.
    func containsLoosely(_ term: String) -> Bool {
        term.isEmpty || range(of: term, options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }
}
