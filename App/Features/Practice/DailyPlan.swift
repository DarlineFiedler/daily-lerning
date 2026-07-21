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
        let calendar = Calendar.current
        func handledToday(_ vocab: Vocab) -> Bool {
            guard let last = vocab.lastPracticedAt else { return false }
            return calendar.isDate(last, inSameDayAs: now)
        }

        let inProgress = vocabs.filter { $0.status == .learning || $0.status == .almostLearned }
        let learned = vocabs.filter { $0.status == .learned }

        let toLearn = inProgress.filter { !handledToday($0) }
        if !toLearn.isEmpty { return Result(kind: .learn, words: toLearn) }

        let toReview = learned.filter { !handledToday($0) }
        if !toReview.isEmpty { return Result(kind: .review, words: toReview) }

        // Nichts mehr offen: „alles erledigt" nur zeigen, wenn überhaupt Wörter im Lernprozess
        // sind (also schon mindestens einmal durchgenommen wurden, Status ≠ „Neu").
        if !inProgress.isEmpty || !learned.isEmpty {
            return Result(kind: .done, words: [])
        }
        return Result(kind: .none, words: [])
    }
}
