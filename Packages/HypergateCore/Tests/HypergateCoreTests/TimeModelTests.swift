import Foundation
import HypergateAstronomyEngine
import HypergateCore
import Testing

private struct ReferenceTimeScale: Decodable {
  let at: Date
  let ttMinusUTCSeconds: Double
}

private struct TimeModelMeasurement: Codable {
  let at: Date
  let referenceTTMinusUTCSeconds: Double
  let providerTTMinusUTCSeconds: Double
  let differenceSeconds: Double
}

@Test func timeModelContributionsAreMeasuredSeparately() async throws {
  let url = try #require(
    Bundle.module.url(forResource: "time-scales", withExtension: "json", subdirectory: "Fixtures"))
  let rows = try UTCDate.decoder().decode([ReferenceTimeScale].self, from: Data(contentsOf: url))
  let provider = AstronomyEngineProvider()
  var measurements: [TimeModelMeasurement] = []
  for row in rows {
    let offset = try await provider.ttMinusUTCSeconds(at: row.at)
    #expect(offset.isFinite)
    measurements.append(
      TimeModelMeasurement(
        at: row.at, referenceTTMinusUTCSeconds: row.ttMinusUTCSeconds,
        providerTTMinusUTCSeconds: offset, differenceSeconds: offset - row.ttMinusUTCSeconds))
  }
  if let path = ProcessInfo.processInfo.environment["HYPERGATE_TIME_MODEL_REPORT"] {
    try UTCDate.encoder().encode(measurements).write(
      to: URL(fileURLWithPath: path), options: .atomic)
  }
}
