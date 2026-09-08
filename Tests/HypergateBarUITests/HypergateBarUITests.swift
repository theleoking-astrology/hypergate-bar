import XCTest

@MainActor final class HypergateBarUITests: XCTestCase {
  func testDashboardNavigationExportCancellationAndQuit() throws {
    let app = XCUIApplication()
    app.launchArguments = ["--dashboard"]
    app.launchEnvironment["HYPERGATE_TEST_DATA"] =
      NSTemporaryDirectory() + "HypergateBar-UI-" + UUID().uuidString
    app.launch()
    let started = app.buttons["Get started"]
    if started.waitForExistence(timeout: 10) { started.click() }
    XCTAssertTrue(app.windows["HypergateBar"].waitForExistence(timeout: 15))
    let planets = app.radioButtons["Planets"]
    XCTAssertTrue(planets.waitForExistence(timeout: 10))
    planets.click()
    XCTAssertTrue(app.tables.firstMatch.waitForExistence(timeout: 10))
    XCTAssertTrue(app.staticTexts["Sun"].exists)
    app.radioButtons["Upcoming"].click()
    XCTAssertTrue(
      app.menuButtons.matching(NSPredicate(format: "label BEGINSWITH 'Event types'")).firstMatch
        .exists)
    app.buttons["Export JSON"].click()
    let cancel = app.buttons["Cancel"]
    XCTAssertTrue(cancel.waitForExistence(timeout: 5))
    cancel.click()
    XCTAssertTrue(app.windows["HypergateBar"].exists)
    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = "HypergateBar UI smoke"
    attachment.lifetime = .keepAlways
    add(attachment)
    app.windows["HypergateBar"].buttons[XCUIIdentifierCloseWindow].click()
    XCTAssertNotEqual(app.state, .notRunning)
    app.terminate()
    XCTAssertEqual(app.state, .notRunning)
  }
}
