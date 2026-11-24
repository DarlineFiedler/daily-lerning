@testable import DailyHangul
import Foundation
import SwiftData
import XCTest

/// Fehlerpfade des [[PersistenceController]] (Issue #183) – genau die Stellen, die schon einmal
/// Datenverlust verursacht haben: Store lässt sich nicht öffnen, App-Group fehlt, Store-Ort.
/// Alle Disk-Tests laufen in einem eigenen Temp-Verzeichnis und fassen weder den echten Store
/// noch das globale `storeOpenFailed`-Flag an.
@MainActor
final class PersistenceControllerTests: XCTestCase {

    private var directory: URL!
    private var storeURL: URL!
    private var defaults: UserDefaults!
    private var suiteName: String!
    // Container MUSS leben, solange sein mainContext benutzt wird – sonst Crash.
    private var container: ModelContainer?

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("PersistenceControllerTests-\(UUID().uuidString)")
        storeURL = directory.appendingPathComponent("default.store")
        // Eindeutig je Test, damit parallele Läufe sich den Marker nicht gegenseitig löschen.
        suiteName = "test.persistence.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
        defaults.removePersistentDomain(forName: suiteName)
        container = nil
        directory = nil
        storeURL = nil
        defaults = nil
        suiteName = nil
    }

    // MARK: - Store öffnen

    /// Gesunder Pfad: Der Store wird auf der Platte angelegt, und Daten überleben ein erneutes Öffnen.
    func testOpenDiskContainerPersistsAcrossReopen() throws {
        do {
            let result = PersistenceController.openDiskContainer(at: storeURL)
            XCTAssertFalse(result.openFailed)
            let context = result.container.mainContext
            context.insert(Vocab(word: "집", meaning: "Haus"))
            try context.save()
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: storeURL.path))

        let reopened = PersistenceController.openDiskContainer(at: storeURL)
        XCTAssertFalse(reopened.openFailed)
        let words = try reopened.container.mainContext.fetch(FetchDescriptor<Vocab>()).map(\.word)
        XCTAssertEqual(words, ["집"])
    }

    /// Fehlendes Zielverzeichnis (Neuinstallation ohne Application Support) wird angelegt.
    func testOpenDiskContainerCreatesMissingDirectory() {
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.path))
        let result = PersistenceController.openDiskContainer(at: storeURL)
        XCTAssertFalse(result.openFailed)
        XCTAssertTrue(FileManager.default.fileExists(atPath: directory.path))
    }

    /// Kaputte Store-Datei: kein Crash, `openFailed` gesetzt, ein nutzbarer, LEERER In-Memory-Store
    /// als Notlösung – und die Datei auf der Platte bleibt unangetastet (kein Überschreiben).
    func testCorruptStoreFallsBackToEmptyInMemoryWithoutTouchingFile() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let garbage = Data(repeating: 0xAB, count: 4096)
        try garbage.write(to: storeURL)

        let result = PersistenceController.openDiskContainer(at: storeURL)

        XCTAssertTrue(result.openFailed)
        let context = result.container.mainContext
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Vocab>()), 0)
        // Notfall-Store muss benutzbar sein (kein Crash beim Schreiben).
        context.insert(Vocab(word: "물", meaning: "Wasser"))
        XCTAssertNoThrow(try context.save())
        // Die Originaldatei wurde nicht durch einen frischen, leeren Store ersetzt.
        XCTAssertEqual(try Data(contentsOf: storeURL), garbage)
        // …und es sind auch keine frischen Sidecar-Dateien (-wal/-shm/-journal) daneben entstanden,
        // die beim nächsten Start mit der Originaldatei kombiniert würden.
        let files = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        XCTAssertEqual(files, ["default.store"])
    }

    /// Ein Ziel, das sich gar nicht anlegen lässt (Elternpfad ist eine Datei), endet ebenfalls im
    /// In-Memory-Notfall statt im Crash.
    func testUncreatableStorePathFallsBackToInMemory() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let blocker = directory.appendingPathComponent("not-a-directory")
        try Data("x".utf8).write(to: blocker)

        let result = PersistenceController.openDiskContainer(
            at: blocker.appendingPathComponent("default.store"))

        XCTAssertTrue(result.openFailed)
        XCTAssertEqual(try result.container.mainContext.fetchCount(FetchDescriptor<Vocab>()), 0)
    }

    // MARK: - Fester Speicherort

    /// Der Store liegt fest unter Application Support/`default.store` – unabhängig von der App-Group.
    func testLocalStoreURLIsFixedInApplicationSupport() {
        let url = PersistenceController.localStoreURL
        XCTAssertEqual(url.lastPathComponent, "default.store")
        XCTAssertEqual(url.deletingLastPathComponent().standardizedFileURL,
                       URL.applicationSupportDirectory.standardizedFileURL)
        if let group = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: AppGroup.identifier) {
            XCTAssertFalse(url.path.hasPrefix(group.path))
        }
    }

    // MARK: - Kein Seeding / keine Wartung bei kaputtem Store

    func testStartupMaintenanceSkippedWhenStoreOpenFailed() throws {
        let container = PersistenceController.makeContainer(inMemory: true)
        self.container = container
        let context = container.mainContext
        var ran = false

        let healthy = StartupMaintenance.runIfStoreHealthy(
            context: context, storeOpenFailed: true, maintenance: { _ in ran = true })

        XCTAssertFalse(healthy)
        XCTAssertFalse(ran)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<VocabGroup>()), 0)
    }

    func testStartupMaintenanceRunsWhenStoreHealthy() {
        let container = PersistenceController.makeContainer(inMemory: true)
        self.container = container
        let context = container.mainContext
        var ran = false

        let healthy = StartupMaintenance.runIfStoreHealthy(
            context: context, storeOpenFailed: false, maintenance: { _ in ran = true })

        XCTAssertTrue(healthy)
        XCTAssertTrue(ran)
    }

    /// Ohne expliziten Parameter entscheidet das globale `storeOpenFailed` – so ruft RootView auf.
    func testStartupMaintenanceDefaultReadsGlobalStoreFlag() {
        let container = PersistenceController.makeContainer(inMemory: true)
        self.container = container
        var ran = false

        let healthy = StartupMaintenance.runIfStoreHealthy(
            context: container.mainContext, maintenance: { _ in ran = true })

        XCTAssertEqual(healthy, !PersistenceController.storeOpenFailed)
        XCTAssertEqual(ran, !PersistenceController.storeOpenFailed)
    }

    // MARK: - App-Group-Fallback der Migration

    /// Ohne App-Group darf die Migration weder Daten anfassen noch sich als erledigt markieren –
    /// sonst wären dort gestrandete Altdaten für immer verloren.
    func testMigrationWithoutAppGroupIsNotConsumed() throws {
        let container = PersistenceController.makeContainer(inMemory: true)
        self.container = container
        let context = container.mainContext
        context.insert(Vocab(word: "책", meaning: "Buch"))
        try context.save()

        StoreMigration.runIfNeeded(into: context, appGroupAvailable: false, defaults: defaults)

        XCTAssertFalse(defaults.bool(forKey: StoreMigration.doneKey))
        XCTAssertEqual(try context.fetch(FetchDescriptor<Vocab>()).map(\.word), ["책"])
    }

    /// Ist die Migration schon erledigt, steigt sie sofort aus – auch bei verfügbarer App-Group.
    func testMigrationAlreadyDoneIsSkipped() throws {
        defaults.set(true, forKey: StoreMigration.doneKey)
        let container = PersistenceController.makeContainer(inMemory: true)
        self.container = container
        let context = container.mainContext

        StoreMigration.runIfNeeded(into: context, appGroupAvailable: true, defaults: defaults)

        XCTAssertTrue(defaults.bool(forKey: StoreMigration.doneKey))
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Vocab>()), 0)
    }
}
