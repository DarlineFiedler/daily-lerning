import Foundation

/// Reine, UI-unabhängige Logik für den Übersetzer: erkennt die Übersetzungsrichtung
/// (Koreanisch ↔ App-Sprache) anhand des Eingabetexts und liefert die passenden
/// Sprach- und TTS-Codes. Bewusst ohne SwiftUI/Translation-Abhängigkeit, damit sie
/// unter [[TranslatorView]] testbar bleibt.
enum TranslationDirection {

    /// Ein Sprachpaar (Quelle → Ziel) als BCP-47-Kurzcodes, z.B. `ko` → `de`.
    struct LanguagePair: Equatable {
        let source: String
        let target: String

        /// TTS-Code (`ko-KR`, `de-DE`, …) für die Quellsprache – für [[SpeakButton]].
        var sourceTTS: String { TranslationDirection.ttsCode(source) }
        /// TTS-Code für die Zielsprache.
        var targetTTS: String { TranslationDirection.ttsCode(target) }
    }

    /// Enthält der Text mindestens ein koreanisches (Hangul-)Zeichen?
    /// Deckt Silbenblöcke, alle Jamo-Blöcke (inkl. Extended-A/B) und die
    /// Halbbreiten-Hangul ab.
    static func containsHangul(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            (0xAC00 ... 0xD7A3).contains(scalar.value) // Hangul-Silben
                || (0x1100 ... 0x11FF).contains(scalar.value) // Jamo
                || (0x3130 ... 0x318F).contains(scalar.value) // kompatible Jamo
                || (0xA960 ... 0xA97F).contains(scalar.value) // Jamo Extended-A
                || (0xD7B0 ... 0xD7FF).contains(scalar.value) // Jamo Extended-B
                || (0xFFA0 ... 0xFFDC).contains(scalar.value) // Halbbreite Hangul
        }
    }

    /// Ermittelt Quell-/Zielsprache für Anzeige und Sprachausgabe: enthält der Text
    /// Hangul, wird von Koreanisch in die App-Sprache übersetzt, sonst umgekehrt.
    /// Die Richtung folgt damit immer dem tatsächlichen Eingabetext (kein separater
    /// Override-Zustand, der aus dem Tritt geraten könnte).
    static func pair(for input: String, appLang: String) -> LanguagePair {
        let koreanIsSource = containsHangul(input)
        return LanguagePair(source: koreanIsSource ? "ko" : appLang,
                            target: koreanIsSource ? appLang : "ko")
    }

    /// Konkrete App-Sprache (Nicht-Korea-Seite) für das Übersetzungspaar. Da Ko↔Ko
    /// sinnlos ist, wird für die UI-Sprache Koreanisch auf Englisch ausgewichen; die
    /// System-Sprache wird auf die unterstützten Etiketten (de/en) geklemmt.
    static func resolvedAppLang(language: LocalizationManager.AppLanguage, deviceCode: String) -> String {
        switch language {
        case .de: return "de"
        case .en: return "en"
        case .ko: return "en"
        case .system: return ["de", "en"].contains(deviceCode) ? deviceCode : "en"
        }
    }

    /// Anzeige-Etikett für einen Sprachcode über die bestehenden `lang.*`-Keys.
    static func label(for code: String) -> String {
        L("lang.\(code)")
    }

    /// Bildet einen Kurzcode auf einen TTS-Sprachcode für `AVSpeechSynthesizer` ab.
    static func ttsCode(_ code: String) -> String {
        switch code {
        case "ko": return "ko-KR"
        case "de": return "de-DE"
        case "en": return "en-US"
        default: return "\(code)-\(code.uppercased())"
        }
    }
}
