import Foundation
import SwiftData
import WidgetKit

/// Eine vorbereitete Lernaufgabe (Wort + zugewiesener Modus/Richtung/Optionen).
struct PracticeItem: Identifiable {
    let id = UUID()
    let vocab: Vocab
    let mode: PracticeMode
    let direction: ResolvedDirection
    /// Für Multiple Choice: 4 gemischte Optionen (inkl. richtiger Antwort).
    let choices: [Vocab]

    func prompt() -> String {
        direction == .wordToMeaning ? vocab.word : vocab.meaning
    }

    func answer() -> String {
        direction == .wordToMeaning ? vocab.meaning : vocab.word
    }

    /// Die anzuzeigende Seite einer Antwortoption (die „Antwort-Seite“).
    func optionText(_ option: Vocab) -> String {
        direction == .wordToMeaning ? option.meaning : option.word
    }
}

/// Steuert einen Lernvorgang: Reihenfolge, Fortschritt, Ergebnisverbuchung.
@MainActor
@Observable
final class PracticeSession {
    private(set) var items: [PracticeItem]
    private let context: ModelContext
    private let distractorPool: [Vocab]
    private let config: PracticeConfig

    var index = 0
    var correctCount = 0
    var wrongCount = 0

    /// Falsch beantwortete Wörter (für Zusammenfassung + „Falsche wiederholen").
    private(set) var missedVocabs: [Vocab] = []
    /// Wörter, deren Status in dieser Session aufgestiegen ist.
    private(set) var leveledUpVocabs: [Vocab] = []
    /// In dieser Runde neu freigeschaltete Badges (für das Freischalt-Feedback).
    private(set) var newlyUnlocked: [Achievement] = []
    /// Wurde ein zuvor falsch beantwortetes Wort in dieser Runde richtig beantwortet?
    /// (für das „Selbstkorrektur"-Badge).
    private var didSelfCorrect = false
    /// Anzahl der in dieser Runde neu auf „gelernt" aufgestiegenen Wörter
    /// (für das „Ein Wort am Tag"-Badge).
    private var newlyLearnedCount = 0
    /// Verhindert, dass die Runden-Auswertung (Achievements) mehrfach läuft.
    private var didFinalize = false
    /// Streak-Aktivität wird pro Session nur einmal verbucht (ist ohnehin idempotent
    /// pro Kalendertag) – spart den vollen UserDefaults-load+save je Folgekarte.
    private var didRegisterStreak = false
    /// Wochen-Log der laufenden Session: im Speicher gesammelt und gebündelt persistiert
    /// (statt den ganzen Log je Karte zu de/encoden). Lazy beim ersten Ergebnis geladen.
    private var weeklyActivity: WeeklyActivity?

    init(vocabs: [Vocab], distractorPool: [Vocab], config: PracticeConfig, context: ModelContext) {
        self.context = context
        self.distractorPool = distractorPool
        self.config = config
        // Wortanzahl begrenzen (nil = alle), danach Aufgaben bauen.
        let picked = config.wordLimit.map { Array(vocabs.shuffled().prefix($0)) } ?? vocabs.shuffled()
        self.items = Self.buildItems(from: picked, distractorPool: distractorPool, config: config)
    }

    var isFinished: Bool { index >= items.count }
    var currentItem: PracticeItem? { isFinished ? nil : items[index] }
    var total: Int { items.count }
    var position: Int { min(index + 1, total) }

    /// Reine Lückentext-Runde? (Steuert die Leer-Meldung, wenn kein Wort einen
    /// Beispielsatz hat.)
    var isClozeOnly: Bool { config.isClozeOnlySession }

    /// „Endgegner"-Modus aktiv? (Issue #89 – rein visuelle Kampf-Schicht.)
    var isBossMode: Bool { config.bossMode }

    /// Aktueller Kampfstand, komplett aus den Zählern abgeleitet.
    var bossBattle: BossBattle {
        BossBattle(total: total, correct: correctCount, wrong: wrongCount)
    }

    /// Die einzige distinkte Vokabelgruppe dieser Runde – für die Boss-Identität
    /// (Name/Farbe). `nil`, wenn die Runde keine oder mehrere Gruppen umfasst.
    var bossGroup: VocabGroup? {
        var found: VocabGroup?
        for item in items {
            guard let group = item.vocab.group else { return nil }
            if let found {
                if found.id != group.id { return nil }
            } else {
                found = group
            }
        }
        return found
    }

    /// Trefferquote in Prozent (0, wenn noch nichts beantwortet).
    var accuracy: Int {
        let answered = correctCount + wrongCount
        return answered == 0 ? 0 : Int(round(Double(correctCount) / Double(answered) * 100))
    }

    /// Verbucht das Ergebnis für das aktuelle Wort und geht zum nächsten.
    /// Kein Widget-Refresh: Üben ändert nur Status/Counter, nie die im Widget
    /// gezeigten Wörter (word/meaning/includeInWidget). Der Snapshot wird beim
    /// App-Start, Wechsel in den Vordergrund und beim Bearbeiten aktualisiert.
    func submit(correct: Bool) {
        guard let item = currentItem else { return }
        record(result: correct, for: item.vocab)
    }

    /// Verbucht ein Ergebnis für ein bestimmtes Wort und rückt den Fortschritt vor.
    /// Im Per-Karte-Fluss ist das Wort `currentItem.vocab` (via `submit`).
    func record(result correct: Bool, for vocab: Vocab) {
        let before = vocab.status
        // Zuvor falsch/zurückgesetzt? (geübt, aber Erfolgs-Counter auf 0) – für „Selbstkorrektur".
        let wasPreviouslyWrong = vocab.timesPracticed > 0 && vocab.successCounter == 0
        vocab.registerResult(correct: correct)
        if correct {
            correctCount += 1
            if wasPreviouslyWrong { didSelfCorrect = true }
            // Aufstieg? (rawValue steigt mit dem Lernfortschritt).
            if vocab.status.rawValue > before.rawValue {
                leveledUpVocabs.append(vocab)
                if vocab.status == .learned, before != .learned { newlyLearnedCount += 1 }
            }
        } else {
            wrongCount += 1
            missedVocabs.append(vocab)
        }
        // Streak nur einmal je Session verbuchen; die Idempotenz pro Kalendertag macht
        // weitere load+save-Runden je Karte überflüssig. Schon der erste Treffer
        // persistiert die Aktivität (überlebt einen früh abgebrochenen Durchgang).
        if !didRegisterStreak {
            StreakStore.registerActivity() // idempotent pro Kalendertag
            didRegisterStreak = true
        }
        // Wochenrückblick füttern: distinct geübtes Wort + evtl. Erstaufstieg auf „Gelernt".
        // Nur im Speicher aggregieren – die Persistenz läuft gebündelt über `flushProgress()`.
        let becameLearned = before != .learned && vocab.status == .learned
        let log = weeklyActivity ?? WeeklyReviewStore.loadActivity()
        weeklyActivity = log.recording(wordID: vocab.id, becameLearned: becameLearned,
                                       correct: correct, on: .now, calendar: .current)
        context.saveOrLog()
        index += 1
        // Endgegner-Modus: sind die Leben aufgebraucht, gewinnt der Boss – die Runde
        // endet sofort (der bestehende `isFinished`/`finalizeRound`-Pfad übernimmt).
        if config.bossMode, bossBattle.isPlayerDefeated { index = items.count }
        if isFinished { finalizeRound() }
    }

    /// Einmalige Auswertung am Rundenende: Übungsrunde verbuchen und ggf. neue
    /// Badges freischalten. Idempotent pro Runde (`didFinalize`).
    private func finalizeRound() {
        guard !didFinalize else { return }
        didFinalize = true
        flushProgress() // gesammelten Wochen-Log am Rundenende persistieren
        let now = Date.now
        // Fehlerfreie Runde mit genug Wörtern → „Makellos". `isFlawless` gilt für die
        // Fehlerfrei-Serie schon ohne Mindestwortzahl.
        let isPerfect = wrongCount == 0 && total >= 5
        let isFlawless = wrongCount == 0 && total >= 1
        // Boss besiegt = im Endgegner-Modus die Runde durchgestanden, ohne k.o. zu gehen.
        let bossDefeated = config.bossMode && bossBattle.playerWon
        newlyUnlocked = AchievementService.registerSession(
            modes: Set(items.map(\.mode)),
            date: now,
            isPerfect: isPerfect,
            isFlawless: isFlawless,
            selfCorrected: didSelfCorrect,
            newlyLearned: newlyLearnedCount,
            currentStreak: StreakStore.current,
            groups: Set(items.compactMap { $0.vocab.group?.id.uuidString }),
            bossDefeated: bossDefeated,
            context: context
        )
        // Üben ändert den Fälligkeitsstand (nextReviewAt/lastPracticedAt) → App-Icon-Badge
        // aktualisieren. Anders als das Widget hängt das Badge an der offenen Wortzahl.
        BadgeUpdater.refresh(context: context)
        // Streak & Ziel-Fortschritt haben sich geändert → gezielt nur das Streak-Widget
        // neu laden (das Wort-Widget hängt nicht am Streak).
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetKind.streak)
    }

    /// Persistiert den in dieser Session gesammelten Wochen-Log. Wird am Rundenende
    /// und beim Verlassen der Ansicht (Schließen/Hintergrund) aufgerufen, damit der
    /// Fortschritt auch einen früh abgebrochenen Durchgang übersteht. No-op, solange
    /// nichts gesammelt wurde; wiederholte Aufrufe schreiben nur denselben Stand.
    func flushProgress() {
        guard let weeklyActivity else { return }
        WeeklyReviewStore.saveActivity(weeklyActivity)
    }

    /// Startet denselben Satz Wörter erneut.
    func restart() {
        resetProgress()
    }

    /// Baut eine neue Runde nur aus den falsch beantworteten Wörtern.
    func retryWrong() {
        let wrong = missedVocabs
        guard !wrong.isEmpty else { return }
        items = Self.buildItems(from: wrong.shuffled(), distractorPool: distractorPool, config: config)
        resetProgress()
    }

    private func resetProgress() {
        index = 0
        correctCount = 0
        wrongCount = 0
        missedVocabs = []
        leveledUpVocabs = []
        newlyUnlocked = []
        didSelfCorrect = false
        newlyLearnedCount = 0
        didFinalize = false
    }

    // MARK: - Aufgaben-Aufbau

    /// Weist jedem Wort einen (zufälligen) Modus, eine aufgelöste Richtung und
    /// – für Auswahl-/Hör-Modi – vier Optionen zu.
    private static func buildItems(from vocabs: [Vocab], distractorPool: [Vocab], config: PracticeConfig) -> [PracticeItem] {
        let perCardModes = config.resolvedModes
        // Session-weite Invarianten der Distraktor-Auswahl EINMAL vorberechnen (statt pro
        // Wort): die Session-IDs, den um sie bereinigten Pool und dessen Gruppierung. Das
        // Gruppieren fasst den teuren SwiftData-`group`-Relationship-Zugriff auf einen
        // einzigen Durchlauf zusammen – vorher wurde der ganze Pool je Wort neu gefiltert
        // und gemischt (O(Wörter × Pool)).
        let sessionIDs = Set(vocabs.map(\.id))
        let remaining = distractorPool.filter { !sessionIDs.contains($0.id) }
        let remainingByGroup = Dictionary(grouping: remaining) { $0.group?.id }
        return vocabs.compactMap { vocab in
            // Lückentext nur für Wörter mit brauchbarem Beispielsatz. Fehlt er, entfällt der
            // Modus für dieses Wort; bleibt dann keiner übrig (nur-Lückentext ohne Beispiel),
            // wird das Wort für diese Runde übersprungen.
            var candidates = perCardModes
            if !ClozeText.canCloze(vocab) { candidates.removeAll { $0 == .cloze } }
            guard let mode = candidates.randomElement() else { return nil }
            // Hör-/Lückentext-Modus: feste Richtung (der Prompt bzw. die Lücke ist das Wort).
            let direction: ResolvedDirection = (mode == .listening || mode == .cloze)
                ? .wordToMeaning : ResolvedDirection.resolve(config.direction)
            // Nur Auswahl-/Hör-Modi brauchen Distraktoren; Lückentext (wie Schreiben/Durchgehen)
            // wird eingetippt bzw. gewischt – die Options-Berechnung entfällt.
            let choices = mode == .cloze ? [] : makeChoices(
                for: vocab, sessionVocabs: vocabs,
                remaining: remaining, remainingByGroup: remainingByGroup, direction: direction
            )
            return PracticeItem(vocab: vocab, mode: mode, direction: direction, choices: choices)
        }
    }

    // MARK: - Multiple-Choice-Optionen

    /// Wählt drei Distraktoren mit eindeutiger Antwortseite (plus das Zielwort) und mischt.
    /// Kandidaten werden nach Nähe zum Zielwort geschichtet, damit die Distraktoren
    /// möglichst Wörter sind, die im Lernvorgang vorkommen (statt nie gesehener
    /// Zufallswörter, unter denen das gesuchte Wort sofort heraussticht):
    /// 1. andere Wörter aus diesem Durchgang → 2. Wörter derselben Gruppe →
    /// 3. Rest des Pools (nur als Auffüllung für kleine Sessions).
    ///
    /// `remaining`/`remainingByGroup` sind bereits um die Session-Wörter bereinigt und
    /// werden vom Aufrufer einmal je Session vorberechnet. Die Tiers werden faul
    /// abgearbeitet und nur so weit gemischt, bis drei Distraktoren stehen – im Normalfall
    /// (genug Session-Wörter) wird der große Pool gar nicht erst angefasst.
    private static func makeChoices(
        for vocab: Vocab,
        sessionVocabs: [Vocab],
        remaining: [Vocab],
        remainingByGroup: [UUID?: [Vocab]],
        direction: ResolvedDirection
    ) -> [Vocab] {
        let answerText: (Vocab) -> String = {
            direction == .wordToMeaning ? $0.meaning : $0.word
        }
        // Das Zielwort ist ausgeschlossen: gleiche ID wird übersprungen und sein
        // Antworttext liegt vorab in `seenAnswers` (kein Distraktor darf denselben
        // Antworttext tragen – sonst wäre die Frage mehrdeutig).
        var seenAnswers: Set<String> = [answerText(vocab)]
        var distractors: [Vocab] = []
        // Nimmt Kandidaten auf, bis drei stehen; meldet, ob damit fertig.
        func collect(_ candidates: [Vocab]) -> Bool {
            for candidate in candidates {
                guard candidate.id != vocab.id else { continue }
                guard seenAnswers.insert(answerText(candidate)).inserted else { continue }
                distractors.append(candidate)
                if distractors.count == 3 { return true }
            }
            return false
        }

        // Tier 1: andere Wörter dieser Runde (nur Referenzen, kein Relationship-Zugriff).
        if !collect(sessionVocabs.shuffled()) {
            if let groupID = vocab.group?.id {
                // Tier 2: restlicher Pool derselben Gruppe.
                if !collect((remainingByGroup[groupID] ?? []).shuffled()) {
                    // Tier 3: übrige Gruppen – nur bei kleinen Runden/Gruppen nötig.
                    let others = remainingByGroup.lazy
                        .filter { $0.key != groupID }
                        .flatMap(\.value)
                    _ = collect(Array(others).shuffled())
                }
            } else {
                // Zielwort ohne Gruppe: der ganze restliche Pool füllt auf.
                _ = collect(remaining.shuffled())
            }
        }
        return ([vocab] + distractors).shuffled()
    }
}

/// Vergleicht Schreib-Antworten (normalisiert, mehrere Varianten via „/“ „,“ „;“).
/// Sowohl die Eingabe als auch die erwartete Antwort werden in Varianten zerlegt,
/// damit z.B. die Eingabe „gehen, laufen“ gegen „gehen / laufen“ matcht.
enum AnswerChecker {
    static func isCorrect(typed: String, expected: String) -> Bool {
        let typedVariants = variants(of: typed)
        guard !typedVariants.isEmpty else { return false }
        return !typedVariants.isDisjoint(with: variants(of: expected))
    }

    /// Zerlegt einen String an „/“ „,“ „;“ in normalisierte, nicht-leere Varianten.
    private static func variants(of s: String) -> Set<String> {
        Set(
            s.split(whereSeparator: { $0 == "/" || $0 == "," || $0 == ";" })
                .map { normalize(String($0)) }
                .filter { !$0.isEmpty }
        )
    }

    private static func normalize(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: nil)
    }
}
