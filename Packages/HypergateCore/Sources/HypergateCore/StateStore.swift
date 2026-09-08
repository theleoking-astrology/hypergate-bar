import Foundation

public protocol StateStorage: Sendable {
  func loadPreferences() async throws -> AppPreferences?
  func savePreferences(_ preferences: AppPreferences) async throws
  func loadEvents() async throws -> EventDocument?
  func saveEvents(_ events: EventDocument) async throws
  func saveRequests(_ requests: [PlannedReminder]) async throws
}

public actor JSONStateStore: StateStorage {
  private let directory: URL
  public init(directory: URL) { self.directory = directory }
  private func read<T: Decodable>(_ name: String, as type: T.Type) throws -> T? {
    let url = directory.appendingPathComponent(name)
    guard FileManager.default.fileExists(atPath: url.path) else { return nil }
    return try UTCDate.decoder().decode(type, from: Data(contentsOf: url))
  }
  private func write<T: Encodable>(_ value: T, name: String) throws {
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try UTCDate.encoder().encode(value).write(
      to: directory.appendingPathComponent(name), options: .atomic)
  }
  public func loadPreferences() throws -> AppPreferences? {
    let preferences = try read("preferences-v1.json", as: AppPreferences.self)
    try preferences?.validate()
    return preferences
  }
  public func savePreferences(_ preferences: AppPreferences) throws {
    try preferences.validate()
    try write(preferences, name: "preferences-v1.json")
  }
  public func loadEvents() throws -> EventDocument? {
    let events = try read("events-v1.json", as: EventDocument.self)
    if let events {
      _ = try EventQuery(
        from: events.query.from, to: events.query.to, bodies: events.query.bodies,
        types: events.query.types)
      guard events.schemaVersion == 1, events.algorithmRevision == EventEngine.algorithmRevision,
        events.complete, events.coverageEnd == events.query.to,
        Set(events.events.map(\.id)).count == events.events.count,
        events.events.allSatisfy({ event in
          !event.id.isEmpty && event.instant >= events.query.from
            && event.instant < events.coverageEnd && events.query.types.contains(event.kind)
            && !event.bodies.isEmpty && event.bodies.allSatisfy(events.query.bodies.contains)
            && (event.longitude == nil
              || (event.longitude?.isFinite == true && (0..<360).contains(event.longitude ?? -1)))
            && (event.aspectAngle == nil || event.kind.angles.contains(event.aspectAngle ?? -1))
        })
      else {
        throw CoreError.invalidArgument("Invalid or unsupported event cache; recalculate it.")
      }
    }
    return events
  }
  public func saveEvents(_ events: EventDocument) throws {
    try write(events, name: "events-v1.json")
  }
  public func saveRequests(_ requests: [PlannedReminder]) throws {
    try write(requests, name: "requests-v1.json")
  }
}
