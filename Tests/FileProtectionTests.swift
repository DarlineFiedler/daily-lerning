@testable import DailyHangul
import Foundation
import XCTest

/// Prüft die bewusst gesetzten Datenschutz-Stufen (Issue #104) für den lokalen SwiftData-Store
/// und den Widget-Snapshot. Data Protection wird auf dem Simulator nicht erzwungen, daher testen
/// wir die bewussten Entscheidungen (Konstanten) sowie den Snapshot-Roundtrip mit den neuen
/// Write-Optionen – nicht die tatsächliche Durchsetzung durch iOS.
final class FileProtectionTests: XCTestCase {

    /// Der Store liest ausschließlich die App im Vordergrund → bewusst auf `.complete` angehoben.
    func testStoreFileProtectionIsComplete() {
        XCTAssertEqual(PersistenceController.storeFileProtection, .complete)
    }

    /// Der Snapshot muss vom Widget bei gesperrtem Gerät lesbar bleiben → bewusst NICHT `.complete`,
    /// sondern `.completeUntilFirstUserAuthentication`, und atomar geschrieben.
    func testSnapshotWriteOptionsKeepWidgetReadableWhileLocked() {
        XCTAssertTrue(WidgetSnapshot.writeOptions.contains(.completeFileProtectionUntilFirstUserAuthentication))
        XCTAssertTrue(WidgetSnapshot.writeOptions.contains(.atomic))
        XCTAssertFalse(WidgetSnapshot.writeOptions.contains(.completeFileProtection))
    }

    /// Das Schreiben mit den neuen Protection-Optionen darf den Snapshot nicht beschädigen:
    /// Roundtrip über einen echten Dateipfad muss identisch zurückdekodieren.
    func testSnapshotRoundTripWithProtectionOptions() throws {
        let words = [WidgetWord(id: UUID(), word: "가다", meaning: "gehen")]
        let snapshot = WidgetSnapshot(words: words, settings: WidgetSettings(intervalMinutes: 15),
                                      generatedAt: Date(timeIntervalSince1970: 1000))

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("snapshot-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }

        let data = try JSONEncoder.snapshotTest.encode(snapshot)
        try data.write(to: url, options: WidgetSnapshot.writeOptions)

        let loaded = try JSONDecoder.snapshotTest.decode(WidgetSnapshot.self,
                                                         from: Data(contentsOf: url))
        XCTAssertEqual(loaded.words, words)
        XCTAssertEqual(loaded.settings.intervalMinutes, 15)
        XCTAssertEqual(loaded.generatedAt, snapshot.generatedAt)
    }
}

private extension JSONEncoder {
    static let snapshotTest: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()
}

private extension JSONDecoder {
    static let snapshotTest: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}
