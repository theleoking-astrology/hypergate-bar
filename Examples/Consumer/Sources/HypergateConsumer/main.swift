import Foundation
import HypergateAstronomyEngine
import HypergateCore

// Consumers inject any Sendable EphemerisProvider; platform UI and notification
// frameworks are not required. No downloaded executable plugin mechanism exists.
let provider: any EphemerisProvider = AstronomyEngineProvider()
let engine = EventEngine(provider: provider)
let start = try UTCDate.parse("2026-09-08T00:00:00Z")
let query = try EventQuery(
  from: start, to: start.addingTimeInterval(7 * 86400), bodies: [.moon], types: [.ingress])
let result = try await engine.events(query)
FileHandle.standardOutput.write(try UTCDate.encoder().encode(result))
FileHandle.standardOutput.write(Data("\n".utf8))
