import Foundation

/// Leichtgewichtiges Spaced-Repetition-Scheduling („SRS-lite", Leitner-artig).
///
/// Bewusst **kein** SM-2 (kein Ease-Faktor, keine Review-History): Passend zum
/// 4-Stufen-Statusmodell reicht eine Intervallkurve auf Basis des vorhandenen
/// `successCounter` (Streak aufeinanderfolgender richtiger Antworten). Zentral
/// definiert, damit alle Lernmodi identisch planen.
enum ReviewSchedule {
    /// Tage bis zur nächsten Fälligkeit, abhängig vom Erfolgs-Counter.
    /// 0 (gerade falsch / neu) → morgen wieder; danach wachsende Abstände.
    static func intervalDays(for successCounter: Int) -> Int {
        switch successCounter {
        case ..<1: return 1   // falsch beantwortet → morgen erneut
        case 1: return 1
        case 2: return 2
        case 3: return 4
        case 4: return 7
        default: return 14    // gelernt (≥ 5) → in zwei Wochen auffrischen
        }
    }

    /// Nächster Fälligkeitszeitpunkt ab `date`, auf Basis des Counters.
    static func nextReviewDate(for successCounter: Int, from date: Date = .now) -> Date {
        let days = intervalDays(for: successCounter)
        return Calendar.current.date(byAdding: .day, value: days, to: date) ?? date
    }
}
