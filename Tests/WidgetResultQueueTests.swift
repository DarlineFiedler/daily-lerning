@testable import DailyHangul
import XCTest

/// Prüft die App-Group-Warteschlange, über die das interaktive Widget Ergebnisse an die App
/// übergibt (`WidgetResultQueue`): append/load/clear-Roundtrip, Kappung und toleranter
/// Leerzustand. In Tests zeigt `AppGroup.containerURL` mangels echter App-Group auf das
/// temporäre Verzeichnis – deshalb vor jedem Test leeren.
final class WidgetResultQueueTests: XCTestCase {

    override func setUp() {
        super.setUp()
        WidgetResultQueue.clear()
    }

    override func tearDown() {
        WidgetResultQueue.clear()
        super.tearDown()
    }

    /// Ohne vorheriges Schreiben (bzw. nach `clear`) ist die Queue leer – kein Fehler.
    func testEmptyWhenNothingWritten() {
        XCTAssertTrue(WidgetResultQueue.load().isEmpty)
    }

    /// Angehängte Ergebnisse kommen in Reihenfolge und mit allen Feldern zurück.
    func testAppendAndLoadRoundtrip() {
        let a = PendingWidgetResult(wordID: UUID(), correct: true, date: Date(timeIntervalSince1970: 100))
        let b = PendingWidgetResult(wordID: UUID(), correct: false, date: Date(timeIntervalSince1970: 200))
        WidgetResultQueue.append(a)
        WidgetResultQueue.append(b)

        XCTAssertEqual(WidgetResultQueue.load(), [a, b])
    }

    /// `clear` leert die Queue vollständig.
    func testClearEmptiesQueue() {
        WidgetResultQueue.append(PendingWidgetResult(wordID: UUID(), correct: true, date: .now))
        WidgetResultQueue.clear()
        XCTAssertTrue(WidgetResultQueue.load().isEmpty)
    }

    /// Über die Obergrenze hinaus wachsen die Einträge nicht: die ältesten fallen weg,
    /// die jüngsten bleiben erhalten.
    func testCapsAtMaxCount() {
        let overflow = WidgetResultQueue.maxCount + 5
        var last: PendingWidgetResult!
        for index in 0 ..< overflow {
            last = PendingWidgetResult(wordID: UUID(), correct: true,
                                       date: Date(timeIntervalSince1970: Double(index)))
            WidgetResultQueue.append(last)
        }

        let loaded = WidgetResultQueue.load()
        XCTAssertEqual(loaded.count, WidgetResultQueue.maxCount)
        XCTAssertEqual(loaded.last, last, "Der jüngste Eintrag muss erhalten bleiben")
    }
}
