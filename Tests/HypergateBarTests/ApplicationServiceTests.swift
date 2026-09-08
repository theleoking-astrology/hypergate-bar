import HypergateCore
import XCTest

@testable import HypergateBar

@MainActor final class ApplicationServiceTests: XCTestCase {
  func testAvailableUpdateCanBeStartedFromMenuAction() {
    let driver = TestUpdateDriver()
    let service = UpdateService(driver: driver)
    driver.onEvent?(.available("0.2.0"))
    XCTAssertEqual(service.actionTitle, "Update to 0.2.0…")
    XCTAssertTrue(service.updateAvailable)
    service.check()
    XCTAssertEqual(driver.checks, 1)
    driver.onEvent?(.capabilities(canCheck: false, automatic: true))
    service.check()
    XCTAssertEqual(driver.checks, 1)
  }

  func testUpdateErrorsDoNotMasqueradeAsCurrentVersion() {
    let driver = TestUpdateDriver()
    let service = UpdateService(driver: driver)
    driver.onEvent?(.available("0.2.0"))
    driver.onEvent?(.failed("Connection unavailable"))
    XCTAssertFalse(service.updateAvailable)
    XCTAssertTrue(service.status.contains("Connection unavailable"))
    driver.onEvent?(.notAvailable)
    XCTAssertEqual(service.status, "No compatible update is available.")
    service.setAutomaticChecks(false)
    XCTAssertFalse(driver.automaticChecks)
  }

  func testInvalidSkyNeverBecomesAvailable() async {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let metadata = AppState.shared.provider.metadata
    let state = AppState(
      provider: MissingSkyProvider(metadata: metadata),
      storage: JSONStateStore(directory: directory)
    )
    await state.refresh()
    XCTAssertNil(state.sky)
    XCTAssertNotNil(state.error)
  }
  func testUnconfiguredUpdaterRemainsDisabled() {
    let service = UpdateService(bundle: Bundle(for: Self.self))
    XCTAssertFalse(service.enabled)
    XCTAssertTrue(service.status.contains("disabled"))
  }
  func testDisplayZoneDoesNotMovePhysicalEvent() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let state = AppState(storage: JSONStateStore(directory: directory))
    let instant = try UTCDate.parse("2026-09-08T19:00:00Z")
    let event = AstroEvent(id: "example", instant: instant, kind: .ingress, bodies: [.moon])
    state.selectedEvent = event
    state.replacePreferences(AppPreferences(displayZone: "Asia/Tokyo"))
    XCTAssertEqual(state.selectedEvent?.instant, instant)
    XCTAssertEqual(state.zone.identifier, "Asia/Tokyo")
  }
}

@MainActor private final class TestUpdateDriver: UpdateDriver {
  var onEvent: ((UpdateEvent) -> Void)?
  var automaticChecks = true
  var checks = 0
  func start() { onEvent?(.capabilities(canCheck: true, automatic: automaticChecks)) }
  func check() { checks += 1 }
}

private struct MissingSkyProvider: EphemerisProvider {
  let metadata: ProviderMetadata
  func positions(at date: Date, bodies: [Body]) async throws -> [Position] { [] }
}
