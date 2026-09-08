import Foundation
import HypergateAstronomyEngine
import HypergateCore
import Testing

private struct ReferencePosition: Decodable {
  let body: Body
  let at: Date
  let longitude: Double
}
private struct ReferenceEvent: Decodable {
  let kind: EventKind
  let bodies: [Body]
  let at: Date
  let target: Double
  let toleranceSeconds: Double
}
private struct AccuracyMeasurement: Codable {
  let category: String
  let bodies: [Body]
  let reference: Date
  let residual: Double
  let limit: Double
  let unit: String
}
private func fixture<T: Decodable>(_ name: String, as type: T.Type) throws -> T {
  let url = try #require(
    Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
  return try UTCDate.decoder().decode(type, from: Data(contentsOf: url))
}

@Test func independentHorizonsAccuracy() async throws {
  let provider = AstronomyEngineProvider()
  let engine = EventEngine(provider: provider)
  var measurements: [AccuracyMeasurement] = []
  for reference in try fixture("positions", as: [ReferencePosition].self) {
    let position = try #require(
      try await provider.positions(at: reference.at, bodies: [reference.body]).first)
    let residual = abs(Angle.difference(position.longitude, reference.longitude)) * 3600
    measurements.append(
      AccuracyMeasurement(
        category: "longitude", bodies: [reference.body], reference: reference.at,
        residual: residual, limit: 60, unit: "arcseconds"))
    #expect(residual <= 60, "\(reference.body) at \(reference.at): \(residual) arcseconds")
  }
  for reference in try fixture("events", as: [ReferenceEvent].self) {
    let query = try EventQuery(
      from: reference.at.addingTimeInterval(-43200), to: reference.at.addingTimeInterval(43200),
      bodies: reference.bodies, types: [reference.kind])
    let document = try await engine.events(query)
    let candidates = document.events.filter { event in
      guard event.kind == reference.kind, Set(event.bodies) == Set(reference.bodies) else {
        return false
      }
      if let angle = event.aspectAngle {
        return abs(Angle.difference(angle, reference.target)) < 0.01
      }
      if reference.kind == .ingress, let longitude = event.longitude {
        return abs(Angle.difference(longitude, reference.target)) < 0.01
      }
      return true
    }
    let closest = try #require(
      candidates.min {
        abs($0.instant.timeIntervalSince(reference.at))
          < abs($1.instant.timeIntervalSince(reference.at))
      }, "Missing reference event: \(reference.kind) \(reference.bodies) \(reference.at)")
    let residual = abs(closest.instant.timeIntervalSince(reference.at))
    measurements.append(
      AccuracyMeasurement(
        category: reference.kind.rawValue, bodies: reference.bodies, reference: reference.at,
        residual: residual, limit: reference.toleranceSeconds, unit: "seconds"))
    #expect(
      residual <= reference.toleranceSeconds,
      "\(reference.kind) \(reference.bodies): \(residual) seconds")
  }
  if let path = ProcessInfo.processInfo.environment["HYPERGATE_ACCURACY_REPORT"] {
    try UTCDate.encoder().encode(measurements).write(
      to: URL(fileURLWithPath: path), options: .atomic)
  }
}
