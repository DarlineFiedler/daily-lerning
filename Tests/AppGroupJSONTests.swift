@testable import DailyHangul
import XCTest

/// Prüft die gemeinsamen JSON-Helfer auf `UserDefaults` (`saveJSON` /
/// `decodeJSONOrPreserve`) samt der gecachten Coder (`AppGroup.jsonEncoder/jsonDecoder`),
/// über die alle UserDefaults-JSON-Stores laufen.
final class AppGroupJSONTests: XCTestCase {

    private struct Sample: Codable, Equatable {
        var count: Int
        var label: String
    }

    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "AppGroupJSONTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testRoundTrip() {
        let value = Sample(count: 7, label: "café")
        defaults.saveJSON(value, forKey: "k")
        let loaded = defaults.decodeJSONOrPreserve(Sample.self, forKey: "k")
        XCTAssertEqual(loaded, value)
    }

    func testMissingKeyReturnsNil() {
        XCTAssertNil(defaults.decodeJSONOrPreserve(Sample.self, forKey: "absent"))
    }

    func testCorruptBlobIsPreservedAndReturnsNil() {
        // Kein gültiges JSON für `Sample` → Decode schlägt fehl.
        let corrupt = Data("not json".utf8)
        defaults.set(corrupt, forKey: "k")

        XCTAssertNil(defaults.decodeJSONOrPreserve(Sample.self, forKey: "k"))
        // Rohbytes wurden einmalig unter "<key>.corrupt" gesichert.
        XCTAssertEqual(defaults.data(forKey: "k.corrupt"), corrupt)
    }

    func testFirstCorruptionWins() {
        let first = Data("first".utf8)
        defaults.set(first, forKey: "k")
        _ = defaults.decodeJSONOrPreserve(Sample.self, forKey: "k")

        // Zweiter korrupter Stand darf die erste (evtl. rettbare) Sicherung nicht überschreiben.
        defaults.set(Data("second".utf8), forKey: "k")
        _ = defaults.decodeJSONOrPreserve(Sample.self, forKey: "k")

        XCTAssertEqual(defaults.data(forKey: "k.corrupt"), first)
    }

    func testCachedCodersAreStableInstances() {
        XCTAssertTrue(AppGroup.jsonEncoder === AppGroup.jsonEncoder)
        XCTAssertTrue(AppGroup.jsonDecoder === AppGroup.jsonDecoder)
    }
}
