import HypergateCore
import XCTest

@testable import HypergateBar

@MainActor final class ApplicationServiceTests: XCTestCase {
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

private struct MissingSkyProvider: EphemerisProvider {
  let metadata: ProviderMetadata
  func positions(at date: Date, bodies: [Body]) async throws -> [Position] { [] }
}
