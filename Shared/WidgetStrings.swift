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

    static var tapHint: String {
        switch languageCode {
        case "de": return "Tippen für Bedeutung"
        case "ko": return "탭하여 뜻 보기"
        default: return "Tap for meaning"
        }
    }

    static var empty: String {
        switch languageCode {
        case "de": return "Keine Wörter"
        case "ko": return "단어 없음"
        default: return "No words"
        }
    }
}
