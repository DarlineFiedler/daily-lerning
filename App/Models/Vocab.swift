import Foundation
import SwiftData

/// Eine einzelne Vokabelkarte.
@Model
final class Vocab {
    var id: UUID = UUID()
    var word: String = "" // Lernsprache (z.B. Hangul)
    var meaning: String = "" // Muttersprache / Bedeutung
    var example: String? // optionaler Freitext (Beispielsatz)

    var statusRaw: Int = LearningStatus.new.rawValue
    var successCounter: Int = 0 // Streak aufeinanderfolgender richtiger Antworten
    var includeInWidget: Bool = false
    var timesPracticed: Int = 0
    var lastPracticedAt: Date?
    /// Nächster Fälligkeitszeitpunkt fürs Wiederholen (SRS-lite). `nil` = noch nie
    /// geplant ⇒ sofort fällig (siehe `isDue`). Additiv eingeführt; SwiftData
    /// migriert bestehende Stores automatisch (Default `nil`).
    var nextReviewAt: Date?
    /// Kalendertag, an dem der `successCounter` zuletzt sein „+1" bekam. Damit lässt sich
    /// ein Wort pro Tag nur einmal hochzählen (siehe `registerResult`). Additiv eingeführt;
    /// SwiftData migriert bestehende Stores automatisch (Default `nil`).
    var lastCountedAt: Date?
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

    /// Ist das Wort zum Wiederholen fällig? Neue/ungeplante Wörter (`nextReviewAt == nil`)
    /// gelten sofort als fällig.
    func isDue(asOf date: Date = .now) -> Bool {
        guard let due = nextReviewAt else { return true }
        return due <= date
    }

    /// Zentrale Ergebnisverarbeitung – von allen Lernmodi genutzt.
    /// Richtig → Counter **einmal pro Kalendertag** +1 (weitere richtige Antworten am selben
    /// Tag zählen nicht mehr). Falsch → Counter jederzeit zurück auf 0 (auch von „Gelernt"
    /// herunter). Status wird neu berechnet und die nächste Fälligkeit (SRS-lite) geplant.
    /// `now` ist injizierbar, damit sich der Tageswechsel testen lässt.
    func registerResult(correct: Bool, now: Date = .now) {
        timesPracticed += 1
        lastPracticedAt = now
        if correct {
            let countedToday = lastCountedAt.map { Calendar.current.isDate($0, inSameDayAs: now) } ?? false
            if !countedToday {
                successCounter += 1
                lastCountedAt = now
            }
        } else {
            successCounter = 0
        }
        statusRaw = LearningStatus.computed(counter: successCounter, practiced: true).rawValue
        nextReviewAt = ReviewSchedule.nextReviewDate(for: successCounter, from: now)
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
            lastCountedAt = nil
            nextReviewAt = nil // zurück auf „sofort fällig"
        case .learning:
            successCounter = LearningStatus.learningThreshold
        case .almostLearned:
            successCounter = LearningStatus.almostLearnedThreshold
        case .learned:
            successCounter = LearningStatus.masteredThreshold
        }
        // Fälligkeit an den (evtl. neu gesetzten) Counter angleichen, außer bei „neu".
        if newStatus != .new {
            nextReviewAt = ReviewSchedule.nextReviewDate(for: successCounter)
        }
    }
}
