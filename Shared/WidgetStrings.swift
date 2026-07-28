import Foundation

/// Minimal lokalisierte Texte für die Widget-Extension (die die App-eigenen
/// String Catalogs nicht einbindet). Liest die gewählte Sprache aus dem
/// geteilten App-Group-UserDefaults.
enum WidgetStrings {
    private static var languageCode: String {
        let raw = AppGroup.defaults.string(forKey: "app.language") ?? "system"
        if raw == "system" {
            return Locale.preferredLanguages.first
                .flatMap { Locale(identifier: $0).language.languageCode?.identifier } ?? "en"
        }
        return raw
    }

    static var empty: String {
        switch languageCode {
        case "de": return "Keine Wörter"
        case "ko": return "단어 없음"
        default: return "No words"
        }
    }

    /// Titel der Live Activity einer laufenden Lernsession.
    static var sessionTitle: String {
        switch languageCode {
        case "de": return "Lernsession"
        case "ko": return "학습 세션"
        default: return "Practice session"
        }
    }

    /// „Wort X von Y" – Fortschrittszeile der Live Activity.
    static func wordProgress(position: Int, total: Int) -> String {
        switch languageCode {
        case "de": return "Wort \(position) von \(total)"
        case "ko": return "\(total)개 중 \(position)번째"
        default: return "Word \(position) of \(total)"
        }
    }

    // MARK: - Streak-Widget

    /// Name des Streak-Widgets im System-Widget-Katalog.
    static var streakDisplayName: String {
        switch languageCode {
        case "de": return "Streak"
        case "ko": return "연속 학습"
        default: return "Streak"
        }
    }

    /// Kurzbeschreibung des Streak-Widgets im Katalog.
    static var streakDescription: String {
        switch languageCode {
        case "de": return "Deine Lern-Serie und dein Ziel-Fortschritt."
        case "ko": return "학습 연속 기록과 목표 진행 상황."
        default: return "Your learning streak and goal progress."
        }
    }

    /// „7 Tage" – Streak-Länge in Tagen.
    static func streakDays(_ count: Int) -> String {
        switch languageCode {
        case "de": return count == 1 ? "1 Tag" : "\(count) Tage"
        case "ko": return "\(count)일"
        default: return count == 1 ? "1 day" : "\(count) days"
        }
    }

    /// Fallback ohne aktive Serie.
    static var noStreak: String {
        switch languageCode {
        case "de": return "Noch keine Serie"
        case "ko": return "아직 연속 기록 없음"
        default: return "No streak yet"
        }
    }

    /// „Längste: N" – längster Streak (Fallback-Zeile ohne Ziel).
    static func longestStreak(_ count: Int) -> String {
        switch languageCode {
        case "de": return "Längste: \(count)"
        case "ko": return "최고: \(count)"
        default: return "Best: \(count)"
        }
    }

    /// Kurz-Label über dem Ring: Tages- bzw. Wochenziel.
    static func goalLabel(isDaily: Bool) -> String {
        switch languageCode {
        case "de": return isDaily ? "Heute" : "Woche"
        case "ko": return isDaily ? "오늘" : "이번 주"
        default: return isDaily ? "Today" : "Week"
        }
    }
}
