import Foundation

/// Grobe TOPIK-Einstufung einer Vokabel (Sprachniveau). Bewusst nur zwei Stufen –
/// TOPIK I (Anfänger, offizielle Level 1–2) und TOPIK II (Fortgeschritten, Level 3–6) –
/// statt der vollen 6-Level-Granularität, weil sich das leichter kuratieren und filtern
/// lässt (siehe Issue #38). `nil` an einer Vokabel bedeutet „nicht eingestuft".
enum TopikLevel: Int, CaseIterable, Identifiable, Codable {
    case one = 1 // TOPIK I  (Anfänger)
    case two = 2 // TOPIK II (Fortgeschritten)

    var id: Int { rawValue }

    /// Kurzform fürs Badge, z.B. „I" / „II" (nicht lokalisiert – römische Ziffer).
    var abbreviation: String {
        switch self {
        case .one: return "I"
        case .two: return "II"
        }
    }

    /// Lokalisierter Anzeigename, z.B. „TOPIK I".
    var titleKey: String {
        switch self {
        case .one: return "topik.i"
        case .two: return "topik.ii"
        }
    }

    /// Parst ein CSV-Feld zu einem Niveau. Akzeptiert römische Kurzform (`I`/`II`, mit
    /// optionalem `TOPIK`-Präfix) sowie offizielle Level-Zahlen 1–6 (1–2 ⇒ TOPIK I,
    /// 3–6 ⇒ TOPIK II). Leere oder unbekannte Werte ergeben `nil`, damit alte Dateien
    /// ohne diese Spalte und Tippfehler unverändert (ohne Einstufung) durchlaufen.
    init?(csv raw: String) {
        let token = raw
            .trimmingCharacters(in: .whitespaces)
            .uppercased()
            .replacingOccurrences(of: "TOPIK", with: "")
            .trimmingCharacters(in: .whitespaces)
        switch token {
        case "I", "1", "2": self = .one
        case "II", "3", "4", "5", "6": self = .two
        default: return nil
        }
    }
}
