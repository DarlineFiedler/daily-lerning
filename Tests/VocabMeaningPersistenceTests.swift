@testable import DailyHangul
import SwiftData
import XCTest

/// Prüft, dass die sprachgetaggten Bedeutungen (Issue #29) über einen **echten**
/// On-Disk-Store hinweg erhalten bleiben. Anders als die übrigen In-Memory-Tests
/// exerziert das die tatsächliche SQLite-Persistenz des JSON-Backing-Felds
/// (`meaningsJSON`) inkl. Schreiben, Schließen und erneutem Öffnen.
@MainActor
final class VocabMeaningPersistenceTests: XCTestCase {

    private var storeURL: URL!

    override func setUpWithError() throws {
        storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("MeaningPersistence-\(UUID().uuidString).store")
    }

    override func tearDownWithError() throws {
        // Store-Datei inkl. WAL/SHM aufräumen.
        for suffix in ["", "-wal", "-shm"] {
            try? FileManager.default.removeItem(
                at: storeURL.deletingLastPathComponent()
                    .appendingPathComponent(storeURL.lastPathComponent + suffix))
        }
        storeURL = nil
    }

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(schema: PersistenceController.schema, url: storeURL)
        return try ModelContainer(for: PersistenceController.schema, configurations: config)
    }

    func testTaggedMeaningsSurviveStoreReopen() throws {
        let id = UUID()
        // 1. Container: Vokabel mit getaggten Bedeutungen schreiben und speichern.
        do {
            let container = try makeContainer()
            let context = container.mainContext
            let v = Vocab(word: "개", meaning: "Hund")
            v.id = id
            v.meaningsByLanguage = ["en": "dog", "fr": "chien"]
            context.insert(v)
            try context.save()
        }

        // 2. Frischer Container auf DERSELBEN Datei – Daten müssen von der Platte kommen.
        let container = try makeContainer()
        let context = container.mainContext
        let loaded = try XCTUnwrap(
            try context.fetch(FetchDescriptor<Vocab>()).first { $0.id == id })
        XCTAssertEqual(loaded.meaning, "Hund")
        XCTAssertEqual(loaded.meaningsByLanguage, ["en": "dog", "fr": "chien"])
    }
}
