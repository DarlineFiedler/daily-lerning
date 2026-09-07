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

    /// Datenschutz-Stufe des lokalen Stores – bewusst auf `.complete` angehoben (Issue #104).
    /// Die Datenbank wird ausschließlich von der App im Vordergrund gelesen: `AppContentRefresh`
    /// läuft nur über `onAppActive`/Vokabeländerungen, es gibt keinen `BGTaskScheduler`-Task und
    /// das Widget nutzt allein den JSON-Snapshot ([[WidgetSnapshotWriter]]), nie die DB. Deshalb
    /// dürfen die Store-Dateien bei gesperrtem Bildschirm unlesbar sein.
    static let storeFileProtection: FileProtectionType = .complete

    static func makeContainer(inMemory: Bool = false) -> ModelContainer {
        if inMemory {
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            // In-Memory-Store kann praktisch nicht scheitern.
            // swiftlint:disable:next force_try
            return try! ModelContainer(for: schema, configurations: config)
        }

        // Application-Support-Verzeichnis sicherstellen (bei Neuinstallation fehlt es).
        try? FileManager.default.createDirectory(
            at: URL.applicationSupportDirectory, withIntermediateDirectories: true)

        let config = ModelConfiguration(schema: schema, url: localStoreURL)
        do {
            let container = try ModelContainer(for: schema, configurations: config)
            applyStoreFileProtection()
            return container
        } catch {
            // Keinen stillen leeren Disk-Store vortäuschen: Fehler protokollieren,
            // Flag setzen und als letzten Ausweg In-Memory öffnen (kein Crash).
            storeLog.fault("Öffnen des Stores fehlgeschlagen: \(error.localizedDescription, privacy: .public)")
            storeOpenFailed = true
            let memoryConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            // Letzter Ausweg; In-Memory-Store kann praktisch nicht scheitern.
            // swiftlint:disable:next force_try
            return try! ModelContainer(for: schema, configurations: memoryConfig)
        }
    }

    /// Hebt die Datenschutz-Stufe der Store-Dateien auf [[storeFileProtection]] an (Issue #104).
    /// Best-effort (`try?`): Das Setzen der Schutzstufe darf den App-Start niemals crashen.
    /// Das Attribut wird auf das Application-Support-Verzeichnis gesetzt (damit später erzeugte
    /// `-wal`/`-shm`-Sidecar-Dateien die Stufe erben) sowie auf alle bereits existierenden
    /// `default.store*`-Dateien.
    private static func applyStoreFileProtection() {
        let fm = FileManager.default
        let attributes: [FileAttributeKey: Any] = [.protectionKey: storeFileProtection]
        let directory = URL.applicationSupportDirectory
        try? fm.setAttributes(attributes, ofItemAtPath: directory.path)

        let storeName = localStoreURL.lastPathComponent
        let names = (try? fm.contentsOfDirectory(atPath: directory.path)) ?? []
        for name in names where name.hasPrefix(storeName) {
            try? fm.setAttributes(attributes, ofItemAtPath: directory.appendingPathComponent(name).path)
        }
    }

    /// Vorschau-Container für SwiftUI-Previews – befüllt aus den mitgelieferten
    /// CSV-Wortpaketen (keine hartcodierten Beispieldaten mehr).
    @MainActor
    static let preview: ModelContainer = {
        let container = makeContainer(inMemory: true)
        let context = container.mainContext
        for pack in WordPack.loadBundled().prefix(2) {
            VocabImporter.importRows(pack.rows, intoGroupNamed: pack.name,
                                     context: context, existingGroups: [])
        }
        context.saveOrLog()
        return container
    }()
}
