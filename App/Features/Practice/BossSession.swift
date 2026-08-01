import Foundation
import SwiftData

/// Eigenständiger „Endgegner"-Kampf (Folge zu #89): rahmt einen Satz Vokabeln als
/// Kampf gegen einen Boss – **vollständig getrennt von den Lern-Statistiken**. Anders
/// als eine `PracticeSession` schreibt der Kampf **nichts** in die Lern-Daten (kein
/// SRS/`registerResult`, kein Streak, kein Wochenrückblick, keine Session-Verbuchung);
/// die Wörter dienen nur als Kampf-Material.
///
/// Mechanik: Boss-HP = Anzahl der Wörter. Jede **richtige** Antwort besiegt ein Wort
/// (HP −1) und nimmt es aus dem Kampf. Jede **falsche** Antwort kostet ein Leben und
/// schickt das Wort zurück in die Warteschlange – so werden **nur die falschen** Wörter
/// wiederholt (Durchgang 2, 3, … enthalten genau die noch offenen). HP 0 → **Sieg**,
/// 0 Leben → **Niederlage**, Aufgeben → **Abbruch** (zählt als Niederlage, kein Badge).
@MainActor
@Observable
final class BossSession {
    private let context: ModelContext
    /// Die ausgewählten Wörter dieser Runde (für `restart`).
    private let vocabs: [Vocab]
    private let distractorPool: [Vocab]
    private let config: PracticeConfig

    /// Boss-Trefferpunkte zu Beginn = Anzahl der (distinkten) Wörter.
    let totalWords: Int
    /// Die einzige Vokabelgruppe der Runde (Boss-Identität: Name/Farbe). `nil`, wenn
    /// die Runde keine oder mehrere Gruppen umfasst → generischer Boss.
    let bossGroup: VocabGroup?

    /// Noch offene (unbesiegte) Wörter des aktuellen Durchgangs; vorne = aktuell dran.
    private var queue: [PracticeItem]
    /// In diesem Durchgang falsch beantwortete Wörter → wandern in den nächsten Durchgang.
    private var pending: [PracticeItem] = []

    private(set) var correctCount = 0
    private(set) var wrongCount = 0
    /// Laufender Durchgang (1 = erster Durchlauf, danach nur noch die falschen).
    private(set) var round = 1
    /// Kampf-Ausgang; `nil` = der Kampf läuft noch.
    private(set) var outcome: BossOutcome?
    /// In dieser Runde neu freigeschaltete Badges (für das Freischalt-Feedback).
    private(set) var newlyUnlocked: [Achievement] = []
    /// Verhindert doppelte Auswertung beim Beenden.
    private var didFinalize = false

    init(vocabs: [Vocab], distractorPool: [Vocab], config: PracticeConfig, context: ModelContext) {
        self.context = context
        self.distractorPool = distractorPool
        self.config = config
        let picked = config.wordLimit.map { Array(vocabs.shuffled().prefix($0)) } ?? vocabs.shuffled()
        self.vocabs = picked
        let built = PracticeSession.buildItems(from: picked, distractorPool: distractorPool, config: config)
        queue = built
        totalWords = built.count
        bossGroup = Self.singleGroup(of: built)
    }

    /// Aktueller Kampfstand (HP/Leben) – rein rechnerisch aus den Zählern abgeleitet.
    var battle: BossBattle { BossBattle(total: totalWords, correct: correctCount, wrong: wrongCount) }

    /// Fortlaufende Antwortzahl – dient als stabile View-ID pro Karte (erzwingt
    /// frischen State, auch wenn dasselbe Wort erneut gefragt wird).
    var turns: Int { correctCount + wrongCount }

    /// Läuft der Kampf noch?
    var isFighting: Bool { outcome == nil }

    /// Aktuell zu beantwortendes Wort (`nil`, wenn der Kampf vorbei ist).
    var currentItem: PracticeItem? { isFighting ? queue.first : nil }

    /// Verbucht eine Antwort: **richtig** besiegt das Wort (HP −1, aus dem Kampf raus),
    /// **falsch** kostet ein Leben und reiht das Wort für den nächsten Durchgang wieder
    /// ein. Beendet den Kampf bei k.o. (Niederlage) oder wenn alle Wörter besiegt sind
    /// (Sieg). Schreibt bewusst **nichts** in die Lern-Daten.
    func answer(correct: Bool) {
        guard isFighting, !queue.isEmpty else { return }
        let item = queue.removeFirst()
        if correct {
            correctCount += 1
        } else {
            wrongCount += 1
            pending.append(item) // nur falsche Wörter kommen wieder
        }
        // Leben aufgebraucht → sofortige Niederlage (hat Vorrang vor allem anderen).
        if battle.isPlayerDefeated { finish(.defeat); return }
        // Durchgang zu Ende?
        guard queue.isEmpty else { return }
        if pending.isEmpty {
            finish(.victory) // alle Wörter besiegt → HP 0
        } else {
            queue = pending // nächster Durchgang: nur die noch offenen (falschen)
            pending = []
            round += 1
        }
    }

    /// Aufgeben: bricht den Kampf ab. Zählt als Niederlage, vergibt aber **kein** Badge.
    func giveUp() {
        guard isFighting else { return }
        finish(.defeat, awardBadge: false)
    }

    /// Startet denselben Satz Wörter als frischen Kampf (neu gemischt).
    func restart() {
        queue = PracticeSession.buildItems(from: vocabs.shuffled(), distractorPool: distractorPool, config: config)
        pending = []
        correctCount = 0
        wrongCount = 0
        round = 1
        outcome = nil
        newlyUnlocked = []
        didFinalize = false
    }

    /// Beendet den Kampf. Ein **Sieg** vergibt – statistik-neutral – nur das
    /// „Boss-Bezwinger"-Flag (Badge-System, keine Lern-Statistik).
    private func finish(_ result: BossOutcome, awardBadge: Bool = true) {
        guard !didFinalize else { return }
        didFinalize = true
        outcome = result
        if result == .victory, awardBadge {
            newlyUnlocked = AchievementService.recordEvent(\.bossDefeated, context: context)
        }
    }

    /// Die einzige distinkte Gruppe aller Items – sonst `nil` (keine/mehrere Gruppen).
    private static func singleGroup(of items: [PracticeItem]) -> VocabGroup? {
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
}
