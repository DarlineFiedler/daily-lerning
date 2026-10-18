import XCTest

/// End-to-End-Flows über die echte App (XCUITest). Bewusst identifier-basiert und damit
/// lokalisierungs-unabhängig: geprüft wird die Verdrahtung UI ↔ Navigation ↔ Persistenz,
/// die reine Unit-Tests nicht abdecken. Die App bietet dafür Debug-Startargumente
/// (`-uiTestSeed` seedet Beispieldaten & überspringt das Onboarding; weitere Args öffnen
/// gezielt einzelne Screens – siehe RootView).
final class DailyHangulUITests: XCTestCase {

    private let timeout: TimeInterval = 15

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// Startet die App mit den gegebenen Startargumenten.
    private func launch(_ arguments: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = arguments
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: timeout),
                      "Die App sollte nach dem Start im Vordergrund laufen.")
        return app
    }

    /// Findet ein Element über seinen Accessibility-Identifier, egal welchen Typs
    /// (Screens/Container sind je nach SwiftUI-Aufbau Button/Other/…).
    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id]
    }

    /// Tippt einen Button über seinen Identifier. Buttons werden bewusst als `.buttons`
    /// adressiert – über die generische `.any`-Abfrage lassen sich interaktive Elemente
    /// für `tap()` nicht zuverlässig auflösen.
    private func tapButton(_ app: XCUIApplication, _ id: String,
                           file: StaticString = #filePath, line: UInt = #line) {
        let button = app.buttons[id]
        XCTAssertTrue(button.waitForExistence(timeout: timeout),
                      "Button '\(id)' sollte vorhanden sein.", file: file, line: line)
        button.tap()
    }

    private func assertExists(_ app: XCUIApplication, _ id: String,
                              file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element(app, id).waitForExistence(timeout: timeout),
                      "Element '\(id)' sollte sichtbar sein.", file: file, line: line)
    }

    /// App startet und zeigt das Garten-Gerüst (kein Crash, bediente Navigation).
    func testAppLaunchesWithGardenShell() {
        let app = launch(["-uiTestSeed"])
        assertExists(app, "screen.garden")
        XCTAssertTrue(app.buttons["practiceFAB"].waitForExistence(timeout: timeout),
                      "Der Üben-FAB sollte in der Tab-Leiste sichtbar sein.")
    }

    /// Tab-Navigation: Garten → Ich → zurück zu Garten, jeweils der richtige Screen.
    func testTabNavigationSwitchesScreens() {
        let app = launch(["-uiTestSeed"])
        assertExists(app, "screen.garden")

        tapButton(app, "tabButton.me")
        assertExists(app, "screen.me")

        tapButton(app, "tabButton.garden")
        assertExists(app, "screen.garden")
    }

    /// Der zentrale Üben-FAB öffnet die Rundenkonfiguration (Sheet).
    func testPracticeFABOpensConfig() {
        let app = launch(["-uiTestSeed"])
        tapButton(app, "practiceFAB")
        assertExists(app, "screen.practiceConfig")
    }

    /// Das Review-Startargument öffnet die Wiederholungs-Session.
    func testReviewDeepLinkShowsReviewScreen() {
        let app = launch(["-uiTestSeed", "-uiTestReview"])
        assertExists(app, "screen.review")
    }

    /// Das Ich-Tab-Startargument wählt direkt den Ich-Tab.
    func testMeTabLaunchArgumentSelectsMeTab() {
        let app = launch(["-uiTestSeed", "-uiTestMeTab"])
        assertExists(app, "screen.me")
    }

    /// Vollständiger Reset wischt alle Daten und führt zurück zum Onboarding – prüft den
    /// Reset-Pfad end-to-end (statt nur der reinen AppReset-Logik im Unit-Test).
    func testFactoryResetReturnsToOnboarding() {
        let app = launch(["-uiTestSeed", "-uiTestReset"])
        assertExists(app, "screen.onboarding")
    }
}
