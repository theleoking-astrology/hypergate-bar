import Foundation
import HypergateAstronomyEngine
import Testing

@testable import HypergateCore

@Test func nextMoonIngressChangesSign() async throws {
  let provider = AstronomyEngineProvider()
  let start = try UTCDate.parse("2026-09-08T19:00:00Z")
  let event = try await IngressSearch.next(body: .moon, after: start, provider: provider)
  #expect(event.instant > start)
  #expect(event.instant.timeIntervalSince(start) < 4 * 86400)
  let before = try await provider.positions(
    at: event.instant.addingTimeInterval(-2), bodies: [.moon])
  let after = try await provider.positions(at: event.instant.addingTimeInterval(2), bodies: [.moon])
  #expect(before[0].sign != after[0].sign)
  #expect(after[0].sign == event.enteredSign)
}
