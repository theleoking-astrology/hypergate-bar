import Foundation
import Testing

@testable import HypergateCore

@Test func cliValidatesAllArguments() throws {
  for args in [
    ["sky", "--at", "2026-01-01T00:00:00Z", "--bogus"],
    ["sky", "--at", "2026-01-01T00:00:00Z", "--bodies", "earth"],
    ["sky", "--at", "2026-01-01T00:00:00Z", "--json", "--json"],
    ["events", "--from", "2026-01-01T00:00:00Z", "--to", "2027-01-01T00:00:00Z"],
    [
      "events", "--from", "2026-01-01T00:00:00Z", "--to", "2026-01-02T00:00:00Z", "--types",
      "trine",
    ],
  ] { #expect(throws: CoreError.self) { try CLIRequest.parse(args) } }
  let parsed = try CLIRequest.parse([
    "events", "--from", "2026-01-01T00:00:00Z", "--to", "2026-01-02T00:00:00Z", "--types",
    "station", "--json",
  ])
  guard case .events(let query, let json) = parsed else {
    Issue.record("Expected events request")
    return
  }
  #expect(json)
  #expect(query.types == [.stationRetrograde, .stationDirect])
}
