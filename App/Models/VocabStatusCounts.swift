import Foundation

extension Sequence where Element == Vocab {
    /// Status-Verteilung in einem einzigen Durchlauf – ersetzt das teurere
    /// `LearningStatus.allCases.map { filter { $0.status == status }.count }`
    /// (O(Status × n)) durch eine Gruppierung (O(n)).
    ///
    /// Liefert ein sparses Dictionary (nur vorkommende Status). Aufrufer greifen
    /// mit `counts[status] ?? 0` zu, daher verhält es sich wie die volle Tabelle.
    func statusCounts() -> [LearningStatus: Int] {
        Dictionary(grouping: self, by: \.status).mapValues(\.count)
    }
}
