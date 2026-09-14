#if DEBUG
import Foundation
import SwiftData

/// **Nur DEBUG / nur zum Testen.** Legt bei leerem Store eine kleine, bunte
/// Beispiel-Datenlage an (Beete mit Wörtern in verschiedenen Lernstufen), damit sich
/// der Garten, die Übungsrunde und die Statistik im Simulator/Preview mit echten
/// Inhalten ansehen lassen.
///
/// Wird ausschließlich ausgelöst, wenn die App mit dem Startargument `-uiTestSeed`
/// gestartet wird (`xcrun simctl launch … -uiTestSeed`). In Release-Builds ist dieser
/// Code nicht vorhanden und kann echte Installationen nie beeinflussen.
enum DemoSeed {
    static var isRequested: Bool {
        CommandLine.arguments.contains("-uiTestSeed")
    }

    @MainActor
    static func insertIfRequestedAndEmpty(into context: ModelContext) {
        guard isRequested else { return }
        let existing = (try? context.fetchCount(FetchDescriptor<VocabGroup>())) ?? 0
        guard existing == 0 else { return }

        let now = Date.now
        let old = Calendar.current.date(byAdding: .day, value: -9, to: now) ?? now

        // (Name, Farbe, [(Wort, Bedeutung, Stufe)], zuletzt geübt)
        let beds: [(String, String, [(String, String, LearningStatus)], Date?)] = [
            ("Verben", "#B23A2C", [
                ("가다", "gehen", .learned), ("먹다", "essen", .learned),
                ("마시다", "trinken", .learned), ("보다", "sehen", .almostLearned),
                ("자다", "schlafen", .learning), ("읽다", "lesen", .new),
                ("쓰다", "schreiben", .almostLearned), ("듣다", "hören", .learned),
            ], now),
            ("Essen & Trinken", "#4F7043", [
                ("사과", "Apfel", .learned), ("밥", "Reis", .almostLearned),
                ("물", "Wasser", .learning), ("김치", "Kimchi", .learned),
                ("커피", "Kaffee", .new), ("차", "Tee", .learning),
            ], now),
            ("Zahlen", "#C98A2B", [
                ("하나", "eins", .learned), ("둘", "zwei", .learned),
                ("셋", "drei", .almostLearned), ("넷", "vier", .learning),
                ("다섯", "fünf", .new),
            ], now),
            ("Grammatik", "#3B82F6", [
                ("은/는", "Themenpartikel", .new), ("이/가", "Subjektpartikel", .new),
                ("을/를", "Objektpartikel", .new), ("에", "Ortspartikel", .new),
            ], old),
        ]

        for (index, bed) in beds.enumerated() {
            let group = VocabGroup(name: bed.0, colorHex: bed.1, sortOrder: index)
            context.insert(group)
            for entry in bed.2 {
                let vocab = Vocab(word: entry.0, meaning: entry.1, group: group)
                vocab.status = entry.2
                vocab.successCounter = entry.2.rawValue
                vocab.timesPracticed = entry.2 == .new ? 0 : 3
                vocab.lastPracticedAt = entry.2 == .new ? nil : bed.3
                context.insert(vocab)
            }
        }
        context.saveOrLog()
    }
}
#endif
