import Foundation
import SwiftData

/// Einmalige Entfernung der früheren, hartcodierten Beispieldaten. Beim ersten Start
/// werden KEINE Vokabeln mehr angelegt – Inhalte kommen jetzt ausschließlich aus den
/// mitgelieferten CSV-Wortpaketen (siehe `WordPack`) bzw. eigenen Importen.
enum SeedData {

    // MARK: - Alt-Beispieldaten entfernen

    /// Namen der ursprünglich geseedeten Beispielgruppen.
    private static let legacyGroupNames: Set<String> = ["Verben", "Essen"]
    /// Koreanische Wörter der ursprünglichen Beispieldaten.
    private static let legacyWords: Set<String> = [
        "가다", "먹다", "마시다", "보다", "사과", "밥", "물", "김치"
    ]
    /// Flag im geteilten UserDefaults: Alt-Seed wurde bereits einmalig entfernt.
    private static let removedFlagKey = "didRemoveLegacySeed"

    /// Entfernt einmalig die alten Beispieldaten („Verben"/„Essen" mit den bekannten
    /// Beispielwörtern). Läuft nur, solange die Gruppe unverändert ist – enthält sie
    /// eigene, hinzugefügte Wörter, bleibt sie erhalten. Danach wird ein Flag gesetzt,
    /// damit später selbst angelegte gleichnamige Gruppen nicht angetastet werden.
    @MainActor
    static func removeLegacySeedIfNeeded(from context: ModelContext) {
        let defaults = AppGroup.defaults
        guard !defaults.bool(forKey: removedFlagKey) else { return }

        let groups = (try? context.fetch(FetchDescriptor<VocabGroup>())) ?? []
        for group in groups where legacyGroupNames.contains(group.name) {
            // Nur löschen, wenn ausschließlich bekannte Beispielwörter enthalten sind.
            guard group.vocabs.allSatisfy({ legacyWords.contains($0.word) }) else { continue }
            context.delete(group) // cascade löscht die zugehörigen Vokabeln
        }
        context.saveOrLog()
        // Flag erst nach erfolgreichem Speichern setzen (sonst kein erneuter Versuch).
        defaults.set(true, forKey: removedFlagKey)
    }
}
