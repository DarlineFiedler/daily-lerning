import SwiftUI

/// Verwaltet die zur Laufzeit umschaltbare UI-Sprache (Deutsch / Englisch / Koreanisch).
/// Die Auswahl wird im App-Group-UserDefaults gespeichert und über einen
/// Bundle-Wechsel angewandt. Bei Sprachwechsel wird die View-Hierarchie über
/// `.id(manager.language)` komplett neu aufgebaut.
@Observable
final class LocalizationManager {
    static let shared = LocalizationManager()

    enum AppLanguage: String, CaseIterable, Identifiable {
        case system, de, en, ko
        var id: String { rawValue }
        var displayNameKey: String { "lang.\(rawValue)" }
    }

    private let storageKey = "app.language"
    private(set) var bundle: Bundle = .main

    var language: AppLanguage {
        didSet {
            AppGroup.defaults.set(language.rawValue, forKey: storageKey)
            updateBundle()
            // Geplante Erinnerung in der neuen Sprache neu aufsetzen.
            NotificationScheduler.rescheduleIfEnabled()
        }
    }

    private init() {
        let raw = AppGroup.defaults.string(forKey: storageKey) ?? AppLanguage.system.rawValue
        language = AppLanguage(rawValue: raw) ?? .system
        updateBundle()
    }

    private func updateBundle() {
        let code: String
        switch language {
        case .system:
            code = Locale.preferredLanguages.first
                .flatMap { Locale(identifier: $0).language.languageCode?.identifier } ?? "en"
        case .de, .en, .ko:
            code = language.rawValue
        }
        if let path = Bundle.main.path(forResource: code, ofType: "lproj"),
           let localized = Bundle(path: path) {
            bundle = localized
        } else {
            bundle = .main
        }
    }

    func localized(_ key: String) -> String {
        bundle.localizedString(forKey: key, value: key, table: nil)
    }

    func localizedFormat(_ key: String, _ args: [CVarArg]) -> String {
        let format = bundle.localizedString(forKey: key, value: key, table: nil)
        return String(format: format, locale: localeForFormatting, arguments: args)
    }

    /// Locale für Datums-/Zahlenformatierung passend zur gewählten Sprache.
    var localeForFormatting: Locale {
        switch language {
        case .system: return .current
        case .de: return Locale(identifier: "de")
        case .en: return Locale(identifier: "en")
        case .ko: return Locale(identifier: "ko")
        }
    }
}

// MARK: - Globale Kurzformen

/// Localisierter String für einen Key.
func L(_ key: String) -> String {
    LocalizationManager.shared.localized(key)
}

/// Localisierter, formatierter String (z.B. "%d Wörter").
func L(_ key: String, _ args: CVarArg...) -> String {
    LocalizationManager.shared.localizedFormat(key, args)
}
