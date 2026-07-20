import XCTest

/// UI-Smoke-Tests: prüfen nur, dass die App überhaupt startet und die
/// Grundnavigation steht. Bewusst schlank und lokalisierungs-unabhängig
/// (zählt Tab-Buttons statt Texte zu prüfen), damit sie in CI stabil laufen.
final class DailyHangulUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// App startet und die Haupt-Navigation (Tab-Leiste) ist da.
    /// Bewusst NICHT an eine feste Tab-Anzahl gekoppelt – das Hinzufügen eines Tabs
    /// soll keinen "Regressions"-Fehlschlag auslösen. Geprüft wird das Smoke-Signal:
    /// App läuft und zeigt eine bediente Tab-Leiste.
    func testAppLaunchesWithTabBar() {
        let app = XCUIApplication()
        app.launch()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(
            tabBar.waitForExistence(timeout: 15),
            "Die Tab-Leiste sollte nach dem Start sichtbar sein."
        )
        XCTAssertGreaterThan(
            tabBar.buttons.count, 0,
            "Die Tab-Leiste sollte mindestens einen Tab zeigen."
        )
    }
}
