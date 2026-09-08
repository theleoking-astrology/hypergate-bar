import Darwin
import Foundation
import HypergateAstronomyEngine
import HypergateCore

@main struct HypergateBenchmark {
  static func main() async throws {
    let provider = AstronomyEngineProvider()
    let engine = EventEngine(provider: provider)
    let start = try UTCDate.parse("2026-09-08T00:00:00Z")
    var rows: [[String: String]] = []
    var before = ProcessInfo.processInfo.systemUptime
    _ = try await provider.positions(at: start, bodies: Body.allCases)
    rows.append([
      "operation": "ten positions",
      "seconds": String(ProcessInfo.processInfo.systemUptime - before),
    ])
    for (name, days) in [("Today cold", 1), ("90 days cold", 90), ("90 days warm", 90)] {
      before = ProcessInfo.processInfo.systemUptime
      let query = try EventQuery(
        from: start, to: start.addingTimeInterval(Double(days) * 86400), types: EventKind.allCases)
      let document = try await engine.events(query)
      rows.append([
        "operation": name, "seconds": String(ProcessInfo.processInfo.systemUptime - before),
        "events": String(document.events.count),
      ])
    }
    var usage = rusage()
    guard getrusage(RUSAGE_SELF, &usage) == 0 else {
      throw CoreError.provider("Cannot read process memory measurement")
    }
    let result: [String: Any] = [
      "measuredAt": UTCDate.string(Date()),
      "os": ProcessInfo.processInfo.operatingSystemVersionString,
      "physicalMemoryBytes": ProcessInfo.processInfo.physicalMemory,
      "peakResidentBytes": usage.ru_maxrss,
      "build": "Swift release optimization", "providerRevision": provider.metadata.revision,
      "operations": rows,
    ]
    FileHandle.standardOutput.write(
      try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys]))
    FileHandle.standardOutput.write(Data("\n".utf8))
  }
}
