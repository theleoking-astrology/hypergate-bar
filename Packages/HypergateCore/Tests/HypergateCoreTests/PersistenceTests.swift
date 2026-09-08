import Foundation
import Testing

@testable import HypergateCore

@Test func persistedSettingsRoundTripAndCorruptionIsExplicit() async throws {
  let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
    "HypergateBar-test-" + UUID().uuidString)
  let store = JSONStateStore(directory: directory)
  let settings = AppPreferences(
    alerts: .defaults.updating(.enabled(true)), displayZone: "America/Los_Angeles")
  try await store.savePreferences(settings)
  #expect(try await store.loadPreferences() == settings)
  try Data("invalid".utf8).write(
    to: directory.appendingPathComponent("preferences-v1.json"), options: .atomic)
  await #expect(throws: (any Error).self) { try await store.loadPreferences() }
}

@Test func eventReconciliationIsOneToOneAndKeepsClosePasses() {
  let date = Date(timeIntervalSince1970: 100000)
  let old = [
    AstroEvent(id: "a", instant: date, kind: .square, bodies: [.mercury, .mars]),
    AstroEvent(
      id: "b", instant: date.addingTimeInterval(1.5), kind: .square, bodies: [.mercury, .mars]),
  ]
  let fresh = [
    AstroEvent(
      id: "new-a", instant: date.addingTimeInterval(0.1), kind: .square, bodies: [.mercury, .mars]),
    AstroEvent(
      id: "new-b", instant: date.addingTimeInterval(1.6), kind: .square, bodies: [.mercury, .mars]),
  ]
  #expect(EventIdentity.reconcile(fresh, previous: old).map(\.id) == ["a", "b"])
}
