import XCTest

/// UI-Smoke-Tests: prüfen nur, dass die App überhaupt startet und die
/// Grundnavigation steht. Bewusst schlank und lokalisierungs-unabhängig
/// (zählt Tab-Buttons statt Texte zu prüfen), damit sie in CI stabil laufen.
final class DailyHangulUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// App startet und zeigt bediente Inhalte (kein Crash, keine leere Fläche).
    /// Der Erststart wird über das Debug-Startargument `-uiTestSeed` übersprungen (setzt
    /// zugleich Beispiel-Daten), damit der Smoke-Test das Garten-Gerüst erreicht.
    /// Bewusst layout-/lokalisierungs-unabhängig: die eigene 3-Tab-Navigation ist keine
    /// System-`UITabBar`, daher wird auf „App im Vordergrund + mindestens ein Button"
    /// geprüft statt auf `app.tabBars`.
    func testAppLaunchesWithGardenShell() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestSeed"]
        app.launch()

        XCTAssertTrue(
            app.wait(for: .runningForeground, timeout: 15),
            "Die App sollte nach dem Start im Vordergrund laufen."
        )
        XCTAssertTrue(
            app.buttons.firstMatch.waitForExistence(timeout: 15),
            "Nach dem Start sollte bediente Navigation (mindestens ein Button) sichtbar sein."
        )
    }
}
