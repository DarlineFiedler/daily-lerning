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
}
