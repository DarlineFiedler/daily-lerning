import Foundation

extension Set {
    /// Schaltet die Zugehörigkeit von `value` um: enthält das Set den Wert, wird er
    /// entfernt, sonst eingefügt. Das Idiom für Auswahl-Mengen (Mehrfachauswahl in
    /// Listen/Filtern) – vorher byte-identisch als lokale `toggle(_:_:)` in mehreren Views.
    mutating func toggle(_ value: Element) {
        if contains(value) { remove(value) } else { insert(value) }
    }
}
