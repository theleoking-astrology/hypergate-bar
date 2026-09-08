import Foundation
import HypergateAstronomyEngine
import HypergateCore
import Testing

@Test func separateProviderInstancesRemainDeterministicConcurrently() async throws {
  let at = try UTCDate.parse("2026-09-08T19:00:00Z")
  let expected = try await AstronomyEngineProvider().positions(at: at, bodies: Body.allCases)
  try await withThrowingTaskGroup(of: [Position].self) { group in
    for _ in 0..<20 {
      group.addTask { try await AstronomyEngineProvider().positions(at: at, bodies: Body.allCases) }
    }
    for try await positions in group { #expect(positions == expected) }
  }
}

@Test func cancelledForecastPropagatesCancellation() async throws {
  let engine = EventEngine(provider: AstronomyEngineProvider())
  let start = try UTCDate.parse("2026-09-08T00:00:00Z")
  let query = try EventQuery(from: start, to: start.addingTimeInterval(90 * 86400))
  let task = Task { try await engine.events(query) }
  task.cancel()
  await #expect(throws: CancellationError.self) { _ = try await task.value }
}

@Test func incompleteProviderOutputFailsExplicitly() async throws {
  let provider = EmptyProvider()
  let at = try UTCDate.parse("2026-09-08T00:00:00Z")
  let engine = EventEngine(provider: provider)
  await #expect(throws: (any Error).self) {
    _ = try await engine.events(EventQuery(from: at, to: at.addingTimeInterval(86400)))
  }
}

private struct EmptyProvider: EphemerisProvider {
  let metadata = AstronomyEngineProvider().metadata
  func positions(at date: Date, bodies: [Body]) async throws -> [Position] { [] }
}
