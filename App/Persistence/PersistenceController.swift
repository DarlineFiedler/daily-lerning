import Foundation
import OSLog
import SwiftData

private let storeLog = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.darlinefiedler.DailyHangul",
    category: "store"
)

/// Erstellt den SwiftData-Container an einem FESTEN, lokalen Speicherort.
///
/// Früher wurde der Store je nach Laufzeit-Verfügbarkeit der App-Group mal im
/// App-Group-Container, mal lokal abgelegt. Bei kostenlosen Apple-Konten (7-Tage-
/// Signatur) kann die App-Group-Provisionierung zwischen Builds wechseln – dann
/// öffnete die App plötzlich einen anderen (leeren) Store und die Wörter waren
/// „weg". Deshalb liegt die Datenbank jetzt IMMER lokal. Das Widget liest ohnehin
/// nur den JSON-Snapshot (siehe [[WidgetSnapshotWriter]]), nicht die Datenbank.
enum PersistenceController {

    static let schema = Schema([VocabGroup.self, Vocab.self])

    /// Fester Speicherort im App-Sandbox-Verzeichnis (überlebt App-Updates,
    /// unabhängig von Entitlements). Bewusst der historische SwiftData-Standardname
    /// `default.store`, damit früher lokal gespeicherte Daten ohne Migration
    /// übernommen werden.
    static var localStoreURL: URL {
        URL.applicationSupportDirectory.appendingPathComponent("default.store")
    }

    /// True, wenn der App-Group-Container zur Laufzeit erreichbar ist. Wird von
    /// [[StoreMigration]] genutzt, um evtl. dort gestrandete Altdaten zu übernehmen.
    static var appGroupIsAvailable: Bool {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: AppGroup.identifier) != nil
    }

    /// Wird gesetzt, wenn der Disk-Store NICHT geöffnet werden konnte und als
    /// Notlösung ein flüchtiger In-Memory-Store läuft. RootView zeigt dann einen
    /// Hinweis und überspringt das Seeding, statt still einen leeren Store zu zeigen.
    private(set) static var storeOpenFailed = false

    static func makeContainer(inMemory: Bool = false) -> ModelContainer {
        if inMemory {
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return try! ModelContainer(for: schema, configurations: config)
        }

        // Application-Support-Verzeichnis sicherstellen (bei Neuinstallation fehlt es).
        try? FileManager.default.createDirectory(
            at: URL.applicationSupportDirectory, withIntermediateDirectories: true)

        let config = ModelConfiguration(schema: schema, url: localStoreURL)
        do {
            return try ModelContainer(for: schema, configurations: config)
        } catch {
            // Keinen stillen leeren Disk-Store vortäuschen: Fehler protokollieren,
            // Flag setzen und als letzten Ausweg In-Memory öffnen (kein Crash).
            storeLog.fault("Öffnen des Stores fehlgeschlagen: \(error.localizedDescription, privacy: .public)")
            storeOpenFailed = true
            let memoryConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return try! ModelContainer(for: schema, configurations: memoryConfig)
        }
    }

    /// Vorschau-Container mit Seed-Daten für SwiftUI-Previews.
    @MainActor
    static let preview: ModelContainer = {
        let container = makeContainer(inMemory: true)
        SeedData.insert(into: container.mainContext)
        return container
    }()
}
