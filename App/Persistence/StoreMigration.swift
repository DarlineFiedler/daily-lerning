import Foundation
import SwiftData

/// Einmalige Übernahme von Daten, die noch im ALTEN App-Group-Store liegen, in den
/// jetzt festen lokalen Store (siehe [[PersistenceController]]). Frühere Builds haben
/// die Datenbank – je nach Signierung – teils im App-Group-Container abgelegt; diese
/// Daten würden sonst unerreichbar wirken. Der Upsert über [[VocabBackup]] mergt
/// id-basiert und überschreibt keine bereits lokal vorhandenen Wörter.
enum StoreMigration {

    /// Versionierter Marker: erst gesetzt, NACHDEM der App-Group-Store erfolgreich
    /// geöffnet wurde. So „verbraucht" ein Start ohne verfügbare App-Group die
    /// Migration nicht – sie wird beim nächsten erreichbaren Start nachgeholt.
    static let doneKey = "migratedFromAppGroup.v1"

    /// - Parameters:
    ///   - appGroupAvailable: Ist der App-Group-Container diesen Start erreichbar? Injizierbar,
    ///     damit Tests den Fallback ohne App-Group prüfen können (Issue #183).
    ///   - defaults: Ablage des Erledigt-Markers (Tests nutzen eine eigene Suite).
    @MainActor
    static func runIfNeeded(into context: ModelContext,
                            appGroupAvailable: Bool = PersistenceController.appGroupIsAvailable,
                            defaults: UserDefaults = .standard) {
        guard !defaults.bool(forKey: doneKey) else { return }

        // App-Group diesen Start nicht erreichbar → später erneut versuchen.
        guard appGroupAvailable else { return }

        let oldConfig = ModelConfiguration(
            schema: PersistenceController.schema,
            groupContainer: .identifier(AppGroup.identifier)
        )
        // SwiftData findet die Store-Datei im App-Group-Container selbst – kein
        // Datei-Raten, keine WAL/SHM-Sonderbehandlung nötig.
        guard let oldContainer = try? ModelContainer(
            for: PersistenceController.schema, configurations: oldConfig) else { return }

        let oldContext = ModelContext(oldContainer)
        let groups = (try? oldContext.fetch(FetchDescriptor<VocabGroup>())) ?? []
        let vocabs = (try? oldContext.fetch(FetchDescriptor<Vocab>())) ?? []

        if !groups.isEmpty || !vocabs.isEmpty {
            let backup = VocabBackup(from: groups, vocabs: vocabs)
            // Lokal vorhandene Daten haben Vorrang: nur fehlende ids ergänzen, damit
            // ein evtl. veralteter App-Group-Stand nicht den aktuellen überschreibt.
            backup.apply(into: context, overwriteExisting: false) // id-erhaltend + saveOrLog
        }

        // Erst jetzt (App-Group war erreichbar & geöffnet) als erledigt markieren.
        defaults.set(true, forKey: doneKey)
    }
}
