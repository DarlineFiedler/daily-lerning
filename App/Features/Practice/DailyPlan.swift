import Foundation

/// Ermittelt den heutigen Tagesplan für die Home-Karte und die Wiederholungs-Session.
///
/// Tagesbasiert (nicht SRS-Intervalle): Ein Wort ist „für heute erledigt", sobald es heute
/// mindestens einmal bearbeitet wurde (`lastPracticedAt` = heute) – egal ob richtig oder falsch.
/// Zentral definiert, damit `HomeView` und `ReviewSessionView` nicht auseinanderdriften.
enum DailyPlan {
    /// Was heute ansteht.
    enum Kind: Equatable {
        case learn // Offene Wörter „Am Lernen" / „Fast gelernt"
        case review // Nur noch „Gelernt"-Wörter aufzufrischen
        case done // Alles für heute erledigt (es gibt aber Wörter im Lernprozess)
        case none // Nichts zu tun (nur neue / keine Wörter)
    }

    struct Result {
        let kind: Kind
        /// Die heute noch offenen Wörter (leer bei `.done`/`.none`).
        let words: [Vocab]
    }

    /// Berechnet den heutigen Plan aus allen Vokabeln. `now` ist injizierbar (Tests).
    static func today(from vocabs: [Vocab], now: Date = .now) -> Result {
        let partition = partition(vocabs, now: now)

        if !partition.toLearn.isEmpty { return Result(kind: .learn, words: partition.toLearn) }
        if !partition.toReview.isEmpty { return Result(kind: .review, words: partition.toReview) }

        // Nichts mehr offen: „alles erledigt" nur zeigen, wenn überhaupt Wörter im Lernprozess
        // sind (also schon mindestens einmal durchgenommen wurden, Status ≠ „Neu").
        if !partition.inProgress.isEmpty || !partition.learned.isEmpty {
            return Result(kind: .done, words: [])
        }
        return Result(kind: .none, words: [])
    }

    /// Anzahl der heute noch offenen Wörter (zu lernen + aufzufrischen) – für das App-Icon-Badge.
    /// Tagesbasiert wie `today(...)`: neue, nie geübte Wörter (Status „Neu") sind ausgeschlossen.
    static func openWordCount(from vocabs: [Vocab], now: Date = .now) -> Int {
        let partition = partition(vocabs, now: now)
        return partition.toLearn.count + partition.toReview.count
    }

    /// Die tagesbasierte Aufteilung aller Vokabeln – gemeinsame Grundlage von
    /// `today(...)` und `openWordCount(...)`.
    private struct Partition {
        /// Alle Wörter im Lernprozess (`learning`/`almostLearned`), unabhängig von heute.
        let inProgress: [Vocab]
        /// Alle bereits gelernten Wörter, unabhängig von heute.
        let learned: [Vocab]
        /// Heute noch offene Lern-Wörter (aus `inProgress`, heute nicht bearbeitet).
        let toLearn: [Vocab]
        /// Heute noch offene Wiederhol-Wörter (aus `learned`, heute nicht bearbeitet).
        let toReview: [Vocab]
    }

    /// Teilt die Vokabeln in die Lern- (`learning`/`almostLearned`) und Wiederhol-Stufe
    /// (`learned`) auf und filtert jeweils die heute schon bearbeiteten heraus.
    private static func partition(_ vocabs: [Vocab], now: Date) -> Partition {
        let calendar = Calendar.current
        func handledToday(_ vocab: Vocab) -> Bool {
            guard let last = vocab.lastPracticedAt else { return false }
            return calendar.isDate(last, inSameDayAs: now)
        }

        let inProgress = vocabs.filter { $0.status == .learning || $0.status == .almostLearned }
        let learned = vocabs.filter { $0.status == .learned }
        return Partition(
            inProgress: inProgress,
            learned: learned,
            toLearn: inProgress.filter { !handledToday($0) },
            toReview: learned.filter { !handledToday($0) }
        )
    }
}
