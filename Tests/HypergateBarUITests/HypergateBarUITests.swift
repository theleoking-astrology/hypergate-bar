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
    XCTAssertTrue(
      app.descendants(matching: .any)["planet-table"].firstMatch.waitForExistence(timeout: 10))
    XCTAssertTrue(app.staticTexts["Sun"].exists)
    app.radioButtons["Upcoming"].click()
    XCTAssertTrue(
      app.descendants(matching: .any)["event-type-filter"].firstMatch.waitForExistence(timeout: 10))
    app.buttons["Export JSON"].click()
    let cancel = app.dialogs["save-panel"].buttons["CancelButton"]
    XCTAssertTrue(cancel.waitForExistence(timeout: 5))
    cancel.click()
    XCTAssertTrue(app.windows["HypergateBar"].exists)
    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = "HypergateBar UI smoke"
    attachment.lifetime = .keepAlways
    add(attachment)
    app.windows["HypergateBar"].buttons[XCUIIdentifierCloseWindow].click()
    XCTAssertNotEqual(app.state, .notRunning)
    let status = app.statusItems.firstMatch
    XCTAssertTrue(status.waitForExistence(timeout: 10))
    status.click()
    XCTAssertTrue(app.buttons["Open Dashboard"].waitForExistence(timeout: 10))
    XCTAssertTrue(app.staticTexts["NEXT MOON INGRESS"].exists)
    XCTAssertTrue(app.buttons["menu-update-action"].exists)
    XCTAssertFalse(app.buttons["menu-update-action"].isEnabled)
    let popover = XCTAttachment(screenshot: app.screenshot())
    popover.name = "Actual MenuBarExtra popover"
    popover.lifetime = .keepAlways
    add(popover)
    app.buttons["Open Dashboard"].click()
    XCTAssertEqual(app.windows.matching(identifier: "HypergateBar").count, 1)
    app.windows["HypergateBar"].buttons[XCUIIdentifierCloseWindow].click()
    status.click()
    app.buttons["Quit HypergateBar"].click()
    XCTAssertTrue(app.wait(for: .notRunning, timeout: 10))
  }
}
