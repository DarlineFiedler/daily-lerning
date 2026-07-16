import Foundation
import SwiftData

/// Beispieldaten für Previews und den ersten App-Start (leicht entfernbar).
enum SeedData {

    @MainActor
    static func insert(into context: ModelContext) {
        let verbs = VocabGroup(name: "Verben", colorHex: "#22C55E", sortOrder: 0)
        let food = VocabGroup(name: "Essen", colorHex: "#F97316", sortOrder: 1)
        context.insert(verbs)
        context.insert(food)

        // Letztes Feld: fürs Lock-Screen-Widget vormarkiert (includeInWidget).
        let samples: [(String, String, String?, VocabGroup, Bool)] = [
            ("가다", "gehen", "학교에 가다 – zur Schule gehen", verbs, true),
            ("먹다", "essen", "밥을 먹다 – Reis essen", verbs, true),
            ("마시다", "trinken", nil, verbs, false),
            ("보다", "sehen / schauen", nil, verbs, false),
            ("사과", "Apfel", nil, food, true),
            ("밥", "Reis / Mahlzeit", nil, food, false),
            ("물", "Wasser", nil, food, true),
            ("김치", "Kimchi", nil, food, false)
        ]

        for (word, meaning, example, group, inWidget) in samples {
            let vocab = Vocab(word: word, meaning: meaning, example: example, group: group)
            vocab.includeInWidget = inWidget
            context.insert(vocab)
        }

        context.saveOrLog()
    }

    /// Legt Seed-Daten nur an, wenn der Store noch komplett leer ist.
    @MainActor
    static func insertIfEmpty(into context: ModelContext) {
        let descriptor = FetchDescriptor<VocabGroup>()
        let existing = (try? context.fetchCount(descriptor)) ?? 0
        guard existing == 0 else { return }
        insert(into: context)
    }
}
