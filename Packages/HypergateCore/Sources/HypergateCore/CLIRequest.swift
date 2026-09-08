import Foundation

public enum CLIRequest: Sendable {
  case sky(Date, [Body], Bool)
  case events(EventQuery, Bool)
  case help
  public static let usage = """
    hypergate sky --at <ISO8601 with offset> [--bodies sun,moon,...] [--json]
    hypergate events --from <ISO8601> --to <ISO8601> [--types ingress,square,opposition,station] [--bodies sun,moon,...] [--json]
    Dates must be inside 2000–2050 UTC; event queries may span at most 90 days.
    Optional types: conjunction,semisquare,sesquiquadrate. Both aspect bodies must be selected.
    """
  public static func parse(_ args: [String]) throws -> CLIRequest {
    if args == ["--help"] || args == ["help"] { return .help }
    guard let command = args.first, command == "sky" || command == "events" else {
      throw CoreError.invalidArgument(usage)
    }
    var values: [String: String] = [:]
    var json = false
    var i = 1
    let allowed =
      command == "sky" ? ["--at", "--bodies"] : ["--from", "--to", "--types", "--bodies"]
    while i < args.count {
      let key = args[i]
      if key == "--json" {
        guard !json else { throw CoreError.invalidArgument("Duplicate --json option.") }
        json = true
        i += 1
        continue
      }
      guard allowed.contains(key), values[key] == nil, i + 1 < args.count,
        !args[i + 1].hasPrefix("--")
      else { throw CoreError.invalidArgument("Unknown, duplicate, or incomplete option: \(key)") }
      values[key] = args[i + 1]
      i += 2
    }
    var bodies = Body.allCases
    if let text = values["--bodies"] {
      bodies = try text.split(separator: ",", omittingEmptySubsequences: false).map {
        guard let body = Body(rawValue: String($0)) else {
          throw CoreError.invalidArgument("Unknown body: \($0)")
        }
        return body
      }
      guard Set(bodies).count == bodies.count else {
        throw CoreError.invalidArgument("Duplicate body filter.")
      }
    }
    if command == "sky" {
      guard let at = values["--at"] else { throw CoreError.invalidArgument("sky requires --at.") }
      return .sky(try UTCDate.parse(at), bodies, json)
    }
    guard let from = values["--from"], let to = values["--to"] else {
      throw CoreError.invalidArgument("events requires --from and --to.")
    }
    var types = EventKind.standard
    if let text = values["--types"] {
      types = try text.split(separator: ",", omittingEmptySubsequences: false).flatMap {
        token -> [EventKind] in
        if token == "station" { return [.stationRetrograde, .stationDirect] }
        guard let kind = EventKind(rawValue: String(token)) else {
          throw CoreError.invalidArgument("Unknown event type: \(token)")
        }
        return [kind]
      }
      guard Set(types).count == types.count else {
        throw CoreError.invalidArgument("Duplicate event type filter.")
      }
    }
    return .events(
      try EventQuery(
        from: UTCDate.parse(from), to: UTCDate.parse(to), bodies: bodies, types: types), json)
  }
}
