import SwiftData

/// Wartung beim App-Start: Altdaten aus dem App-Group-Store übernehmen ([[StoreMigration]])
/// und alte Beispielwörter entfernen ([[SeedData]]).
///
/// Läuft NUR, wenn der Disk-Store sauber geöffnet wurde. Ist [[PersistenceController]]
/// auf den flüchtigen In-Memory-Notfall-Store ausgewichen (`storeOpenFailed`), darf nichts
/// hineingeschrieben werden – sonst sähe die Nutzerin einen scheinbar „neuen“ Datenbestand,
/// während ihre echten Daten auf der Platte liegen. Aus RootView herausgezogen, damit diese
/// Entscheidung testbar ist (Issue #183).
enum StartupMaintenance {

    /// - Returns: `true`, wenn der Store gesund war und die Wartung lief; `false`, wenn der
    ///   Store nicht geöffnet werden konnte (der Aufrufer zeigt dann den Fehlerhinweis).
    @MainActor
    @discardableResult
    static func runIfStoreHealthy(
        context: ModelContext,
        storeOpenFailed: Bool = PersistenceController.storeOpenFailed,
        maintenance: @MainActor (ModelContext) -> Void = standardMaintenance
    ) -> Bool {
        guard !storeOpenFailed else { return false }
        maintenance(context)
        return true
    }

    @MainActor
    static func standardMaintenance(_ context: ModelContext) {
        StoreMigration.runIfNeeded(into: context)
        SeedData.removeLegacySeedIfNeeded(from: context)
    }
}
