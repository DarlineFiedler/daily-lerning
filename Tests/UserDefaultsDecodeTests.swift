@testable import DailyHangul
import XCTest

/// Prüft den Decode-Schutz (`UserDefaults.decodeJSONOrPreserve`): ein korrupter JSON-Blob
/// darf nicht still verworfen werden, sondern wird unter `<key>.corrupt` gesichert, bevor der
/// Aufrufer auf seinen Default zurückfällt – sonst überschreibt der nächste `save()` evtl.
/// per Hand rettbare Daten (Streak/XP/Wochen-/Ziel-Historie).
final class UserDefaultsDecodeTests: XCTestCase {

    private var d: UserDefaults!
    private let key = "test.decode.key"

    override func setUp() {
        super.setUp()
        d = UserDefaults(suiteName: "test.decode.suite")!
        d.removeObject(forKey: key)
        d.removeObject(forKey: key + ".corrupt")
    }

    override func tearDown() {
        d.removePersistentDomain(forName: "test.decode.suite")
        d = nil
        super.tearDown()
    }

    private struct Sample: Codable, Equatable { var value: Int }

    /// Fehlt der Wert, gibt es `nil` und keine Sicherung.
    func testMissingValueReturnsNil() {
        XCTAssertNil(d.decodeJSONOrPreserve(Sample.self, forKey: key))
        XCTAssertNil(d.object(forKey: key + ".corrupt"))
    }

    /// Ein gültiger Blob dekodiert normal und erzeugt keine Sicherung.
    func testValidValueDecodes() throws {
        let data = try JSONEncoder().encode(Sample(value: 42))
        d.set(data, forKey: key)

        XCTAssertEqual(d.decodeJSONOrPreserve(Sample.self, forKey: key), Sample(value: 42))
        XCTAssertNil(d.object(forKey: key + ".corrupt"))
    }

    /// Ein korrupter Blob liefert `nil`, wird aber unter `<key>.corrupt` gesichert.
    func testCorruptValueIsPreserved() {
        let corrupt = Data("nicht json".utf8)
        d.set(corrupt, forKey: key)

        XCTAssertNil(d.decodeJSONOrPreserve(Sample.self, forKey: key))
        XCTAssertEqual(d.data(forKey: key + ".corrupt"), corrupt,
                       "Der korrupte Rohwert muss gesichert werden.")
    }

    /// Eine schon vorhandene Sicherung wird nicht überschrieben (erste Korruption gewinnt).
    func testExistingBackupNotOverwritten() {
        let first = Data("erste".utf8)
        d.set(first, forKey: key + ".corrupt")
        d.set(Data("zweite korrupte".utf8), forKey: key)

        XCTAssertNil(d.decodeJSONOrPreserve(Sample.self, forKey: key))
        XCTAssertEqual(d.data(forKey: key + ".corrupt"), first)
    }
}
