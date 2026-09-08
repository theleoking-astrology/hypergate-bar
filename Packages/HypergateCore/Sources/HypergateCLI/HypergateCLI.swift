import Foundation
import HypergateAstronomyEngine
import HypergateCore

@main
struct HypergateCLI {
  static func main() async {
    do {
      let provider = AstronomyEngineProvider()
      switch try CLIRequest.parse(Array(CommandLine.arguments.dropFirst())) {
      case .help:
        output(CLIRequest.usage)
      case .sky(let date, let bodies, let json):
        let positions = try await provider.positions(at: date, bodies: bodies)
        let document = SkySnapshot(
          provider: provider.metadata, at: date, calculatedAt: Date(), positions: positions)
        if json {
          try outputJSON(document)
        } else {
          output("\(UTCDate.string(date)) · \(provider.metadata.convention)")
          for p in positions {
            output("\(p.body.name): \(p.sign.name) \(p.degreeText) · \(p.motion())")
          }
        }
      case .events(let query, let json):
        let document = try await EventEngine(provider: provider).events(query)
        if json {
          try outputJSON(document)
        } else {
          output(
            "Calculated \(UTCDate.string(query.from)) — \(UTCDate.string(document.coverageEnd))")
          for event in document.events {
            output("\(UTCDate.string(event.instant))  \(event.title)")
          }
          if document.events.isEmpty { output("No matching event within this calculated window.") }
        }
      }
    } catch {
      let code: String
      switch error {
      case CoreError.invalidArgument: code = "invalid_argument"
      case CoreError.unsupportedDate: code = "unsupported_date"
      case CoreError.workBudgetExceeded: code = "work_budget_exceeded"
      default: code = "calculation_failed"
      }
      let value =
        ["schemaVersion": 1, "error": ["code": code, "message": String(describing: error)]]
        as [String: Any]
      if let data = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]) {
        FileHandle.standardError.write(data)
        FileHandle.standardError.write(Data("\n".utf8))
      }
      exit(2)
    }
  }
  static func output(_ text: String) { FileHandle.standardOutput.write(Data((text + "\n").utf8)) }
  static func outputJSON<T: Encodable>(_ value: T) throws {
    FileHandle.standardOutput.write(try UTCDate.encoder().encode(value))
    output("")
  }
}
