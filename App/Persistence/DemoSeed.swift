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
    private struct Word {
        let hangul: String
        let meaning: String
        let status: LearningStatus
        init(_ hangul: String, _ meaning: String, _ status: LearningStatus) {
            self.hangul = hangul
            self.meaning = meaning
            self.status = status
        }
    }

    private struct Bed {
        let name: String
        let colorHex: String
        let fallow: Bool
        let words: [Word]
    }

    static var isRequested: Bool {
        CommandLine.arguments.contains("-uiTestSeed")
    }

    @MainActor
    static func insertIfRequestedAndEmpty(into context: ModelContext) {
        guard isRequested else { return }
        let existing = (try? context.fetchCount(FetchDescriptor<VocabGroup>())) ?? 0
        guard existing == 0 else { return }

        let now = Date.now
        // „Gestern" geübt → Wörter sind heute wieder fällig (DailyPlan ist tagesbasiert),
        // damit sich Garten-Fälligkeit und Übungsrunde mit Inhalt testen lassen.
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now) ?? now
        let old = Calendar.current.date(byAdding: .day, value: -9, to: now) ?? now

        let beds: [Bed] = [
            Bed(name: "Verben", colorHex: "#B23A2C", fallow: false, words: [
                Word("가다", "gehen", .learned), Word("먹다", "essen", .learned),
                Word("마시다", "trinken", .learned), Word("보다", "sehen", .almostLearned),
                Word("자다", "schlafen", .learning), Word("읽다", "lesen", .new),
                Word("쓰다", "schreiben", .almostLearned), Word("듣다", "hören", .learned)
            ]),
            Bed(name: "Essen & Trinken", colorHex: "#4F7043", fallow: false, words: [
                Word("사과", "Apfel", .learned), Word("밥", "Reis", .almostLearned),
                Word("물", "Wasser", .learning), Word("김치", "Kimchi", .learned),
                Word("커피", "Kaffee", .new), Word("차", "Tee", .learning)
            ]),
            Bed(name: "Zahlen", colorHex: "#C98A2B", fallow: false, words: [
                Word("하나", "eins", .learned), Word("둘", "zwei", .learned),
                Word("셋", "drei", .almostLearned), Word("넷", "vier", .learning),
                Word("다섯", "fünf", .new)
            ]),
            Bed(name: "Grammatik", colorHex: "#3B82F6", fallow: true, words: [
                Word("은/는", "Themenpartikel", .new), Word("이/가", "Subjektpartikel", .new),
                Word("을/를", "Objektpartikel", .new), Word("에", "Ortspartikel", .new)
            ])
        ]

        for (index, bed) in beds.enumerated() {
            let group = VocabGroup(name: bed.name, colorHex: bed.colorHex, sortOrder: index)
            context.insert(group)
            for word in bed.words {
                let vocab = Vocab(word: word.hangul, meaning: word.meaning, group: group)
                vocab.status = word.status
                vocab.successCounter = word.status.rawValue
                vocab.timesPracticed = word.status == .new ? 0 : 3
                vocab.lastPracticedAt = word.status == .new ? nil : (bed.fallow ? old : yesterday)
                context.insert(vocab)
            }
        }
        context.saveOrLog()

        // Beispiel-Ziele, damit Ziel-Ring & Wochenziel-Fuß im Garten sichtbar sind.
        AppGroup.defaults.set(10, forKey: GoalKeys.daily)
        AppGroup.defaults.set(50, forKey: GoalKeys.weekly)
    }
}
#endif
