import Foundation

/// Deterministische, zeit-verankerte Widget-Rotation.
///
/// Statt die Wörter in fixer Reihenfolge durchzugehen, wird für jeden Zeit-Slot
/// ein Wort aus einer **zufälligen Permutation** gewählt. Pro Durchlauf (`count`
/// Slots) kommt jedes Wort genau einmal dran; jeder Durchlauf hat dank
/// `seed ^ cycle` eine andere Reihenfolge (man kann sich "nach X kommt Z" nicht
/// merken). Weil alles rein aus `(slot, count, seed)` folgt, liefert die Funktion
/// für denselben Zeitpunkt immer dasselbe Wort — das Widget springt beim
/// App-Öffnen also nicht mehr auf Wort 1 zurück.
enum WidgetRotation {

    /// SplitMix64 – kleiner, schneller, deterministischer PRNG (keine Deps).
    private static func next(_ state: inout UInt64) -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// Fisher-Yates-Shuffle der Indizes `0..<count`, gesteuert vom Seed.
    static func seededPermutation(count: Int, seed: UInt64) -> [Int] {
        var indices = Array(0..<max(count, 0))
        guard indices.count > 1 else { return indices }
        var state = seed
        var i = indices.count - 1
        while i > 0 {
            let j = Int(next(&state) % UInt64(i + 1))
            indices.swapAt(i, j)
            i -= 1
        }
        return indices
    }

    /// Index des Wortes, das im gegebenen Slot angezeigt werden soll.
    /// `slot` ist die Anzahl abgelaufener Intervalle seit dem Anker.
    static func wordIndex(forSlot slot: Int, count: Int, seed: UInt64) -> Int {
        guard count > 1 else { return 0 }
        let cycle = slot / count
        let pos = slot % count
        let cycleSeed = seed ^ UInt64(bitPattern: Int64(cycle))
        return seededPermutation(count: count, seed: cycleSeed)[pos]
    }
}
