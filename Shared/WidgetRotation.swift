import Foundation

/// Deterministische, zeit-verankerte Widget-Rotation.
///
/// Statt die Wörter in fixer Reihenfolge durchzugehen, wird für jeden Zeit-Slot
/// ein Wort aus einer **zufälligen Permutation** gewählt. Pro Durchlauf
/// (`wordCount` Slots) kommt jedes Wort genau einmal dran; jeder Durchlauf hat
/// dank `seed ^ cycle` eine andere Reihenfolge (man kann sich "nach X kommt Z"
/// nicht merken). Weil alles rein aus `(slot, wordCount, seed)` folgt, liefert
/// die Funktion für denselben Zeitpunkt immer dasselbe Wort — das Widget springt
/// beim App-Öffnen also nicht mehr auf Wort 1 zurück.
enum WidgetRotation {

    /// SplitMix64 – kleiner, schneller, deterministischer PRNG (keine Deps).
    private static func next(_ state: inout UInt64) -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// Gleichverteilte Zufallszahl in `0..<upperBound` ohne Modulo-Bias
    /// (Rejection-Sampling). `upperBound` muss > 0 sein.
    private static func next(_ state: inout UInt64, upperBound: UInt64) -> UInt64 {
        // Verwerfe das oberste, nicht vollständig abbildbare Restfenster,
        // damit alle Werte exakt gleich wahrscheinlich sind.
        let threshold = (0 &- upperBound) % upperBound
        while true {
            let r = next(&state)
            if r >= threshold { return r % upperBound }
        }
    }

    /// Seed für einen einzelnen Durchlauf (`cycle`) – Basis für dessen Permutation.
    static func cycleSeed(_ cycle: Int, seed: UInt64) -> UInt64 {
        seed ^ UInt64(bitPattern: Int64(cycle))
    }

    /// Fisher-Yates-Shuffle der Indizes `0..<wordCount`, gesteuert vom Seed.
    static func seededPermutation(wordCount: Int, seed: UInt64) -> [Int] {
        var indices = Array(0 ..< max(wordCount, 0))
        guard indices.count > 1 else { return indices }
        var state = seed
        var i = indices.count - 1
        while i > 0 {
            let j = Int(next(&state, upperBound: UInt64(i + 1)))
            indices.swapAt(i, j)
            i -= 1
        }
        return indices
    }

    /// Index des Wortes, das im gegebenen Slot angezeigt werden soll.
    /// `slot` ist die Anzahl abgelaufener Intervalle seit dem Anker.
    ///
    /// Für ganze Timeline-Bereiche ist `seededPermutation(wordCount:seed:)` pro
    /// Zyklus effizienter (siehe `VocabTimelineProvider`); diese Bequemlichkeits-
    /// funktion baut die Permutation für jeden Aufruf neu auf.
    static func wordIndex(forSlot slot: Int, wordCount: Int, seed: UInt64) -> Int {
        guard wordCount > 1 else { return 0 }
        let cycle = slot / wordCount
        let pos = slot % wordCount
        return seededPermutation(wordCount: wordCount, seed: cycleSeed(cycle, seed: seed))[pos]
    }
}
