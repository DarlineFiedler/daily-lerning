import Foundation
import SwiftData

/// Eine einzelne Vokabelkarte.
@Model
final class Vocab {
    var id: UUID = UUID()
    var word: String = ""          // Lernsprache (z.B. Hangul)
    var meaning: String = ""       // Muttersprache / Bedeutung
    var example: String?           // optionaler Freitext (Beispielsatz)

    var statusRaw: Int = LearningStatus.new.rawValue
    var successCounter: Int = 0    // Streak aufeinanderfolgender richtiger Antworten
    var includeInWidget: Bool = false
    var timesPracticed: Int = 0
    var lastPracticedAt: Date?
    var createdAt: Date = Date.now

    var group: VocabGroup?

    init(word: String,
         meaning: String,
         example: String? = nil,
         group: VocabGroup? = nil) {
        self.id = UUID()
        self.word = word
        self.meaning = meaning
        self.example = example
        self.group = group
        self.createdAt = .now
    }

    // MARK: - Status

    var status: LearningStatus {
        get { LearningStatus(rawValue: statusRaw) ?? .new }
        set { statusRaw = newValue.rawValue }
    }

    var hasBeenPracticed: Bool { timesPracticed > 0 }

    /// Zentrale Ergebnisverarbeitung – von allen Lernmodi genutzt.
    /// Richtig → Counter +1, Falsch → Counter zurück auf 0. Status wird neu berechnet.
    func registerResult(correct: Bool) {
        timesPracticed += 1
        lastPracticedAt = .now
        successCounter = correct ? successCounter + 1 : 0
        statusRaw = LearningStatus.computed(counter: successCounter, practiced: true).rawValue
    }

    /// Manuelles Setzen des Status (überschreibt die automatische Berechnung).
    /// Richtet den Counter passend aus, damit späteres Lernen sinnvoll fortsetzt.
    func setStatusManually(_ newStatus: LearningStatus) {
        statusRaw = newStatus.rawValue
        switch newStatus {
        case .new:
            successCounter = 0
            timesPracticed = 0
            lastPracticedAt = nil
        case .learning:
            successCounter = LearningStatus.learningThreshold
        case .almostLearned:
            successCounter = LearningStatus.almostLearnedThreshold
        case .learned:
            successCounter = LearningStatus.masteredThreshold
        }
    }
}
