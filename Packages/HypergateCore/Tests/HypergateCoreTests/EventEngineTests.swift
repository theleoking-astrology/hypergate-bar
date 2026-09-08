import Foundation
import Testing

@testable import HypergateCore

private let epoch = Date(timeIntervalSince1970: 172800)

struct SyntheticProvider: EphemerisProvider {
  let function: @Sendable (Body, Double) -> (Double, Double)
  let metadata = ProviderMetadata(
    name: "Synthetic", revision: "1", convention: "analytic",
    earliest: Date(timeIntervalSince1970: 0),
    latestExclusive: Date(timeIntervalSince1970: 8_640_000))
  func positions(at date: Date, bodies: [Body]) async throws -> [Position] {
    let hours = date.timeIntervalSince(epoch) / 3600
    return try bodies.map { body in
      let (longitude, hourlyVelocity) = function(body, hours)
      return try Position(
        body: body, longitude: longitude, latitude: 0, velocity: hourlyVelocity * 24)
    }
  }
}

@Test func findsTwoIngressesWithSameEndpointSigns() async throws {
  let provider = SyntheticProvider { _, h in (29.9 + (h - 2) * (h - 2), 2 * (h - 2)) }
  let engine = EventEngine(provider: provider)
  let query = try EventQuery(
    from: epoch, to: epoch.addingTimeInterval(6 * 3600), bodies: [.mercury], types: [.ingress])
  let events = try await engine.events(query).events
  #expect(events.count == 2)
  #expect(events.first?.enteredSign == .aries)
  #expect(events.last?.enteredSign == .taurus)
}

@Test func classifiesStationByDerivativeSign() async throws {
  let provider = SyntheticProvider { _, h in (40 - (h - 2) * (h - 2), -2 * (h - 2)) }
  let engine = EventEngine(provider: provider)
  let query = try EventQuery(
    from: epoch, to: epoch.addingTimeInterval(6 * 3600), bodies: [.mercury],
    types: [.stationRetrograde, .stationDirect])
  let events = try await engine.events(query).events
  #expect(events.count == 1)
  #expect(events.first?.kind == .stationRetrograde)
  #expect(abs((events.first?.instant.timeIntervalSince(epoch) ?? 0) - 7200) < 1)
}

@Test func repeatedAspectsAndOverlappingQueriesKeepIdentities() async throws {
  let provider = SyntheticProvider { body, h in
    body == .sun ? (0, 0) : (89.9 + (h - 2) * (h - 2), 2 * (h - 2))
  }
  let engine = EventEngine(provider: provider)
  let whole = try await engine.events(
    EventQuery(
      from: epoch, to: epoch.addingTimeInterval(6 * 3600), bodies: [.sun, .mars], types: [.square]))
  let overlapping = try await engine.events(
    EventQuery(
      from: epoch.addingTimeInterval(3600), to: epoch.addingTimeInterval(4 * 3600),
      bodies: [.sun, .mars], types: [.square]))
  #expect(whole.events.count == 2)
  #expect(whole.events.map(\.id) == overlapping.events.map(\.id))
  #expect(Set(whole.events.map(\.id)).count == 2)
}

@Test func boundaryIsHalfOpenAndWrapsPiscesToAries() async throws {
  let provider = SyntheticProvider { _, h in (359 + h, 1) }
  let engine = EventEngine(provider: provider)
  let boundary = epoch.addingTimeInterval(3600)
  let a = try await engine.events(
    EventQuery(from: epoch, to: boundary, bodies: [.moon], types: [.ingress]))
  let b = try await engine.events(
    EventQuery(
      from: boundary, to: epoch.addingTimeInterval(7200), bodies: [.moon], types: [.ingress]))
  #expect(a.events.isEmpty)
  #expect(b.events.count == 1)
  #expect(b.events.first?.enteredSign == .aries)
}

@Test func ingressTangencyDoesNotChangeSign() async throws {
  let provider = SyntheticProvider { _, h in (30 + (h - 2) * (h - 2), 2 * (h - 2)) }
  let engine = EventEngine(provider: provider)
  let result = try await engine.events(
    EventQuery(
      from: epoch, to: epoch.addingTimeInterval(4 * 3600), bodies: [.mercury], types: [.ingress]))
  #expect(result.events.isEmpty)
}

@Test func budgetAndInvalidRangeFailExplicitly() async throws {
  #expect(throws: CoreError.self) {
    try EventQuery(from: epoch, to: epoch.addingTimeInterval(91 * 86400))
  }
  let provider = SyntheticProvider { _, h in (h, 1) }
  let engine = EventEngine(provider: provider, evaluationBudget: 1)
  await #expect(throws: CoreError.self) {
    try await engine.events(EventQuery(from: epoch, to: epoch.addingTimeInterval(86400)))
  }
}
