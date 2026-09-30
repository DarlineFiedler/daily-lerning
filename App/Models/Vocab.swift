import Foundation
import SwiftData

/// Eine einzelne Vokabelkarte.
@Model
final class Vocab {
    var id: UUID = UUID()
    var word: String = "" // Lernsprache (z.B. Hangul)
    var meaning: String = "" // Muttersprache / Bedeutung (untagged Primär-/Fallback-Wert)
    /// JSON-kodierte Ablage der sprachgetaggten Bedeutungen (Issue #29). Bewusst als
    /// **String** persistiert und nicht als natives `[String: String]`-Attribut: ein
    /// Textfeld mit Default migriert per SwiftData-Lightweight-Migration verlustfrei
    /// (wie `word`/`meaning`), während ein neu hinzugefügtes Dictionary-Attribut die
    /// Migration eines bestehenden Stores gefährden kann. Zugriff ausschließlich über
    /// die berechnete `meaningsByLanguage`; nie direkt lesen/schreiben.
    private var meaningsJSON: String = "{}"
    var example: String? // optionaler Freitext (Beispielsatz)
    /// Optionale visuelle Merkhilfe (ein Emoji). Wird beim Anlegen/Bearbeiten anhand der
    /// Bedeutung automatisch vorgeschlagen (siehe [[EmojiSuggestionService]]), ist aber
    /// jederzeit manuell änderbar/entfernbar. Additiv eingeführt; SwiftData migriert
    /// bestehende Stores automatisch (Default `nil` = kein Emoji).
    var emoji: String?
    /// Rohwert der optionalen TOPIK-Einstufung (siehe [[TopikLevel]]); `nil` = nicht
    /// eingestuft. Wird beim Import aus der optionalen 4. CSV-Spalte gefüllt und ist im
    /// Editor manuell änderbar. Additiv eingeführt; SwiftData migriert bestehende Stores
    /// automatisch (Default `nil`).
    var topikRaw: Int?

    var statusRaw: Int = LearningStatus.new.rawValue
    /// Fortschritts-Counter, aus dem sich Status und Wiederhol-Intervall ableiten. Steigt bei
    /// einer richtigen Antwort einmal pro Kalendertag um 1; ein Fehler senkt ihn um höchstens
    /// eine Stufe (siehe `registerResult` / `LearningStatus.counterAfterLapse`) – er ist also
    /// kein reiner „Streak aufeinanderfolgender richtiger Antworten" mehr.
    var successCounter: Int = 0
    var includeInWidget: Bool = false
    var timesPracticed: Int = 0
    /// Gesamtzahl aller falschen Antworten über die Lebenszeit des Worts (additiv zu
    /// `timesPracticed`). Anders als `successCounter` (der auf max. eine Stufe je Fehler
    /// absinkt) akkumuliert dieser Wert und erlaubt eine Fehlerquote (siehe `isProblemWord`).
    /// Additiv eingeführt; SwiftData migriert bestehende Stores automatisch (Default 0).
    var totalWrongCount: Int = 0
    /// War die **letzte** verbuchte Antwort falsch? Anders als `successCounter == 0` bleibt
    /// dieser Indikator korrekt, seit ein Fehler den Counter nicht mehr hart auf 0 setzt
    /// (Issue #118): Er markiert ein aktuell schwächelndes Wort für `isProblemWord` und die
    /// Selbstkorrektur-Erkennung. Additiv eingeführt; SwiftData migriert bestehende Stores
    /// automatisch (Default `false`).
    var lastAnswerWasWrong: Bool = false
    /// Hat das Wort im Laufe seines Lebens **schon einmal** den Status „gelernt" erreicht?
    /// Damit zählt der Wochenrückblick/`newlyLearned` ein Wort nur beim **Erstaufstieg** als
    /// „neu gelernt" – ein nach einem Lapse erneut gelerntes Wort bläht die Statistik nicht auf
    /// (Issue #118). Additiv eingeführt; SwiftData migriert bestehende Stores automatisch
    /// (Default `false`).
    var everReachedLearned: Bool = false
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
         topik: TopikLevel? = nil,
         group: VocabGroup? = nil) {
        self.id = UUID()
        self.word = word
        self.meaning = meaning
        self.example = example
        self.topikRaw = topik?.rawValue
        self.group = group
        self.createdAt = .now
    }

    // MARK: - Status

    var status: LearningStatus {
        get { LearningStatus(rawValue: statusRaw) ?? .new }
        set { statusRaw = newValue.rawValue }
    }

    /// Getippte Sicht auf `topikRaw` (siehe [[TopikLevel]]). `nil` = nicht eingestuft.
    var topikLevel: TopikLevel? {
        get { topikRaw.flatMap(TopikLevel.init(rawValue:)) }
        set { topikRaw = newValue?.rawValue }
    }

    // MARK: - Mehrsprachige Bedeutungen

    /// Zusätzliche, sprachgetaggte Bedeutungen (Sprachcode → Bedeutung, z.B.
    /// `["en": "dog"]`). Erlaubt es, zu ein und demselben Wort mehrere
    /// Bedeutungssprachen parallel zu pflegen (Issue #29). `meaning` bleibt der untagged
    /// Primär-/Fallback-Wert, sodass bestehende Daten und alle Consumer unverändert
    /// weiterlaufen; getaggte Bedeutungen werden über `meaning(forLanguage:)` bevorzugt.
    /// Berechnet aus/nach `meaningsJSON` (siehe dort, warum als String persistiert).
    var meaningsByLanguage: [String: String] {
        get {
            guard let data = meaningsJSON.data(using: .utf8),
                  let dict = try? JSONDecoder().decode([String: String].self, from: data)
            else { return [:] }
            return dict
        }
        set {
            // Stabile Schlüsselreihenfolge → deterministischer String, keine unnötigen Writes.
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            if let data = try? encoder.encode(newValue),
               let json = String(data: data, encoding: .utf8) {
                meaningsJSON = json
            } else {
                meaningsJSON = "{}"
            }
        }
    }

    /// Normalisiert einen Sprachcode für die Verwendung als Schlüssel (getrimmt,
    /// kleingeschrieben), damit „DE", „de " und „de" denselben Eintrag treffen.
    static func normalizeLanguageCode(_ code: String) -> String {
        code.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// Bedeutung in der gewünschten Sprache. `code == nil` (oder leer) liefert die
    /// untagged Primärbedeutung (`meaning`). Ist für die gewählte Sprache keine
    /// (nicht-leere) Bedeutung gepflegt, wird auf `meaning` zurückgefallen (Issue #29,
    /// Entscheidung „Fallback auf vorhandene Sprache").
    func meaning(forLanguage code: String?) -> String {
        guard let code else { return meaning }
        let normalized = Self.normalizeLanguageCode(code)
        guard !normalized.isEmpty,
              let tagged = meaningsByLanguage[normalized],
              !tagged.isEmpty else { return meaning }
        return tagged
    }

    /// Sortierte Liste der Sprachcodes, für die eine nicht-leere getaggte Bedeutung
    /// existiert. Die untagged `meaning` ist hier bewusst nicht enthalten – sie ist der
    /// Fallback, keine benannte Sprache.
    var availableMeaningLanguages: [String] {
        meaningsByLanguage
            .filter { !$0.value.isEmpty }
            .keys
            .sorted()
    }

    /// Setzt (oder entfernt) die getaggte Bedeutung für eine Sprache. Ein leerer Text
    /// entfernt den Eintrag, damit `availableMeaningLanguages` nicht auf leere Werte
    /// zeigt. Der Sprachcode wird normalisiert (siehe `normalizeLanguageCode`).
    func setMeaning(_ text: String, forLanguage code: String) {
        let key = Self.normalizeLanguageCode(code)
        guard !key.isEmpty else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            meaningsByLanguage[key] = nil
        } else {
            meaningsByLanguage[key] = trimmed
        }
    }

    var hasBeenPracticed: Bool { timesPracticed > 0 }

    /// Mindestanzahl an Versuchen, ab der ein Wort als „Problemwort" gelten kann –
    /// verhindert Ausreißer bei 1–2 Fehlversuchen.
    static let problemMinAttempts = 3
    /// Fehlerquote, ab der (streng größer) ein Wort auffällig ist.
    static let problemWrongRateThreshold = 0.4

    /// Oft falsch beantwortet **und** aktuell schwächelnd. Die Mindestversuche verhindern
    /// Ausreißer bei wenigen Fehlversuchen; `lastAnswerWasWrong` macht die Auswahl
    /// selbstheilend – die nächste richtige Antwort holt das Wort wieder aus den Problemwörtern.
    /// Bewusst an `lastAnswerWasWrong` statt `successCounter == 0` gekoppelt, damit auch ein
    /// gelapstes „gelerntes"/„fast gelerntes" Wort (Counter > 0, letzte Antwort falsch) erkannt
    /// wird, seit ein Fehler den Counter nicht mehr hart auf 0 setzt (Issue #118).
    var isProblemWord: Bool {
        timesPracticed >= Self.problemMinAttempts &&
            lastAnswerWasWrong &&
            Double(totalWrongCount) / Double(timesPracticed) > Self.problemWrongRateThreshold
    }

    /// Ist das Wort zum Wiederholen fällig? Neue/ungeplante Wörter (`nextReviewAt == nil`)
    /// gelten sofort als fällig.
    func isDue(asOf date: Date = .now) -> Bool {
        guard let due = nextReviewAt else { return true }
        return due <= date
    }

    /// Zentrale Ergebnisverarbeitung – von allen Lernmodi genutzt.
    /// Richtig → Counter **einmal pro Kalendertag** +1 (weitere richtige Antworten am selben
    /// Tag zählen nicht mehr). Falsch („Lapse") → Counter sinkt um höchstens **eine Stufe**
    /// (`LearningStatus.counterAfterLapse`): ein gelerntes Wort fällt auf „fast gelernt", nicht
    /// ganz nach unten (Issue #118); neue/lernende Wörter fallen weiterhin auf 0. Status wird
    /// neu berechnet und die nächste Fälligkeit (SRS-lite) geplant.
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
            successCounter = LearningStatus.counterAfterLapse(successCounter)
            totalWrongCount += 1
        }
        lastAnswerWasWrong = !correct
        let newStatus = LearningStatus.computed(counter: successCounter, practiced: true)
        statusRaw = newStatus.rawValue
        if newStatus == .learned { everReachedLearned = true }
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
            totalWrongCount = 0
            lastPracticedAt = nil
            lastCountedAt = nil
            lastAnswerWasWrong = false
            everReachedLearned = false
            nextReviewAt = nil // zurück auf „sofort fällig"
        case .learning:
            successCounter = LearningStatus.learningThreshold
        case .almostLearned:
            successCounter = LearningStatus.almostLearnedThreshold
        case .learned:
            successCounter = LearningStatus.masteredThreshold
            everReachedLearned = true
        }
        // Fälligkeit an den (evtl. neu gesetzten) Counter angleichen, außer bei „neu".
        if newStatus != .new {
            nextReviewAt = ReviewSchedule.nextReviewDate(for: successCounter)
        }
    }
}
