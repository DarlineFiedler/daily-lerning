import Foundation

extension Sequence where Element == Vocab {
    /// Status-Verteilung in einem einzigen Durchlauf – ersetzt das teurere
    /// `LearningStatus.allCases.map { filter { $0.status == status }.count }`
    /// (O(Status × n)) durch eine Gruppierung (O(n)).
    ///
    /// Liefert ein sparses Dictionary (nur vorkommende Status). Aufrufer greifen
    /// mit `counts[status] ?? 0` zu, daher verhält es sich wie die volle Tabelle.
    ///
    /// `reduce(into:)` zählt direkt hoch, statt (wie `Dictionary(grouping:)`) erst
    /// die Wörter je Status in Arrays zu sammeln – gleiches O(n), ohne die
    /// Zwischen-Arrays zu allozieren.
    func statusCounts() -> [LearningStatus: Int] {
        reduce(into: [:]) { $0[$1.status, default: 0] += 1 }
    }
}
