@testable import DailyHangul
import SwiftData
import XCTest

/// Prüft die Change-Detection beim Vordergrund-Wechsel
/// (`AppContentRefresh.shouldRefreshOnActive`): voll auffrischen nur beim ersten Aufruf
/// oder bei einem Tageswechsel – reine App-Switches am selben Tag werden übersprungen.
@MainActor
final class AppContentRefreshTests: XCTestCase {

    private let calendar = Calendar.current

    override func tearDown() {
        // Injizierten Store-Zustand immer zurücksetzen, damit andere Tests unberührt bleiben.
        AppContentRefresh.isStoreVolatile = { PersistenceController.storeOpenFailed }
        super.tearDown()
    }

    /// Issue #163: Läuft nur der flüchtige Notfall-Store, darf eine Vokabel-Änderung Widget-
    /// Snapshot und Badge NICHT auffrischen (sonst Überschreiben mit Wegwerf-Daten).
    func testAfterVocabChangeSkipsWhenStoreIsVolatile() {
        // Container festhalten: Ein nur über `mainContext` referenzierter Container wird
        // sofort freigegeben und der Kontext-Zugriff crasht.
        let container = PersistenceController.makeContainer(inMemory: true)
        let context = container.mainContext
        context.insert(Vocab(word: "가다", meaning: "gehen"))
        AppContentRefresh.isStoreVolatile = { true }
        XCTAssertFalse(AppContentRefresh.afterVocabChange(context: context))
    }

    /// Gegenprobe: Mit intaktem Store wird wie gewohnt aufgefrischt.
    func testAfterVocabChangeRefreshesWhenStoreIsIntact() {
        // Container festhalten: Ein nur über `mainContext` referenzierter Container wird
        // sofort freigegeben und der Kontext-Zugriff crasht.
        let container = PersistenceController.makeContainer(inMemory: true)
        let context = container.mainContext
        AppContentRefresh.isStoreVolatile = { false }
        XCTAssertTrue(AppContentRefresh.afterVocabChange(context: context))
    }

    /// Standardmäßig spiegelt der Schalter das echte Store-Flag (im Testlauf: Store ist offen).
    func testIsStoreVolatileDefaultsToPersistenceFlag() {
        XCTAssertEqual(AppContentRefresh.isStoreVolatile(), PersistenceController.storeOpenFailed)
    }

    /// Beim ersten Aufruf (kein bekannter letzter Refresh) muss immer aufgefrischt werden,
    /// damit Widget/Badge nach einem Kaltstart garantiert frisch sind.
    func testRefreshesOnFirstCall() {
        XCTAssertTrue(AppContentRefresh.shouldRefreshOnActive(lastRefreshDay: nil, now: .now))
    }

    /// Gleicher Kalendertag (nur andere Uhrzeit) → reiner App-Switch → kein Refresh.
    func testSkipsWithinSameDay() {
        let morning = date(2026, 7, 30, hour: 8)
        let evening = date(2026, 7, 30, hour: 21)
        let lastDay = calendar.startOfDay(for: morning)
        XCTAssertFalse(AppContentRefresh.shouldRefreshOnActive(lastRefreshDay: lastDay, now: evening))
    }

    /// Neuer Kalendertag (Tageswechsel) → wieder auffrischen (Streak/Badge tagesbasiert).
    func testRefreshesOnNewDay() {
        let today = calendar.startOfDay(for: date(2026, 7, 30, hour: 23))
        let tomorrow = date(2026, 7, 31, hour: 1)
        XCTAssertTrue(AppContentRefresh.shouldRefreshOnActive(lastRefreshDay: today, now: tomorrow))
    }

    /// Springt die Uhr/Zeitzone zurück (früherer Tag), zählt das als Änderung → auffrischen.
    /// Entscheidend ist die Ungleichheit des Kalendertags, nicht „später".
    func testRefreshesWhenClockMovesBack() {
        let today = calendar.startOfDay(for: date(2026, 7, 30, hour: 12))
        let yesterday = date(2026, 7, 29, hour: 12)
        XCTAssertTrue(AppContentRefresh.shouldRefreshOnActive(lastRefreshDay: today, now: yesterday))
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }
}
