import XCTest

/// UI-Smoke-Tests: prüfen nur, dass die App überhaupt startet und die
/// Grundnavigation steht. Bewusst schlank und lokalisierungs-unabhängig
/// (zählt Tab-Buttons statt Texte zu prüfen), damit sie in CI stabil laufen.
final class DailyHangulUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// App startet und zeigt die fünf Haupt-Tabs aus `RootView`.
    func testAppLaunchesWithFiveTabs() {
        let app = XCUIApplication()
        app.launch()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(
            tabBar.waitForExistence(timeout: 15),
            "Die Tab-Leiste sollte nach dem Start sichtbar sein."
        )
        XCTAssertEqual(
            tabBar.buttons.count, 5,
            "RootView definiert fünf Haupt-Tabs."
        )
    }
}
