import Foundation
import SwiftData
import WidgetKit

/// „Alles zurücksetzen": versetzt die App vollständig in den Auslieferungszustand –
/// wie beim allerersten Start. Löscht alle Vokabeln & Beete, verwirft sämtliche
/// Einstellungen und Fortschritte (Ziel, Streak, XP, Erfolge, Tages-Challenge, Ziel-
/// Historie, Widget-Einstellungen, Erinnerung/Badge, Sprache) und springt über das
/// zurückgesetzte Onboarding-Flag zurück zur Begrüßung.
enum AppReset {
    @MainActor
    static func factoryReset(context: ModelContext) {
        // 1) Alle Modelldaten löschen (lokaler SwiftData-Store).
        try? context.delete(model: Vocab.self)
        try? context.delete(model: VocabGroup.self)
        context.saveOrLog()

        // 2) App-Einstellungen & Fortschritte (App-Group-Suite) komplett verwerfen.
        AppGroup.defaults.removePersistentDomain(forName: AppGroup.identifier)

        // 3) App-lokale Standard-Defaults (Presets + „Heute"-Auswahl). Der Migrations-
        //    Marker in UserDefaults.standard bleibt bewusst erhalten, damit gelöschte
        //    Daten nicht aus dem alten App-Group-Store zurückwandern (siehe StoreMigration).
        PracticePresetStore.resetAll()
        ["reviewDirection", "reviewModes", "reviewWordLimit", "reviewMeaningLanguage"]
            .forEach { UserDefaults.standard.removeObject(forKey: $0) }

        // 4) Geplante Erinnerungen abbestellen und App-Icon-Badge löschen.
        NotificationScheduler.cancel()
        BadgeUpdater.setBadge(0)

        // 5) Begrüßung erzwingen: Onboarding-Flag explizit auf „nicht abgeschlossen".
        //    Das feuert die KVO-Änderung, sodass RootView sofort zur OnboardingView
        //    wechselt (removePersistentDomain allein löst @AppStorage nicht zuverlässig aus).
        AppGroup.defaults.set(false, forKey: OnboardingState.completedKey)

        // 6) Widgets in den leeren Zustand neu laden.
        WidgetCenter.shared.reloadAllTimelines()
    }
}
