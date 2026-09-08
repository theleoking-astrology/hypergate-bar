import Foundation

public enum MenuLabelMode: String, CaseIterable, Codable, Sendable {
  case standard, compact, iconOnly
}
public struct AppPreferences: Codable, Sendable, Equatable {
  public let schemaVersion: Int
  public let alerts: AlertPreferences
  public let displayZone: String?
  public let labelMode: MenuLabelMode
  public let countdown: Bool
  public let majorOrb: Double
  public let minorOrb: Double
  public let stationaryThreshold: Double
  public let introduced: Bool
  public init(
    alerts: AlertPreferences = .defaults, displayZone: String? = nil,
    labelMode: MenuLabelMode = .standard,
    countdown: Bool = false, majorOrb: Double = 3, minorOrb: Double = 1,
    stationaryThreshold: Double = 0.01, introduced: Bool = false
  ) {
    schemaVersion = 1
    self.alerts = alerts
    self.displayZone = displayZone
    self.labelMode = labelMode
    self.countdown = countdown
    self.majorOrb = majorOrb
    self.minorOrb = minorOrb
    self.stationaryThreshold = stationaryThreshold
    self.introduced = introduced
  }
  public func validate() throws {
    try alerts.validate()
    guard schemaVersion == 1, displayZone == nil || TimeZone(identifier: displayZone ?? "") != nil,
      majorOrb.isFinite, minorOrb.isFinite, stationaryThreshold.isFinite,
      (0...15).contains(majorOrb), (0...15).contains(minorOrb),
      (0...1).contains(stationaryThreshold)
    else {
      throw CoreError.invalidArgument("Invalid or unsupported preferences document.")
    }
  }
}

public enum EventIdentity {
  /// Greedy nearest matching over all candidate edges prevents one old event
  /// being assigned to two fresh roots. Distinct search passes remain distinct.
  public static func reconcile(_ fresh: [AstroEvent], previous: [AstroEvent]) -> [AstroEvent] {
    var edges: [(Int, Int, Double)] = []
    for (i, event) in fresh.enumerated() {
      for (j, old) in previous.enumerated()
      where event.kind == old.kind && event.bodies == old.bodies
        && event.enteredSign == old.enteredSign && event.aspectAngle == old.aspectAngle
      {
        let distance = abs(event.instant.timeIntervalSince(old.instant))
        if distance <= 2 { edges.append((i, j, distance)) }
      }
    }
    edges.sort { $0.2 == $1.2 ? ($0.0 == $1.0 ? $0.1 < $1.1 : $0.0 < $1.0) : $0.2 < $1.2 }
    var assignments: [Int: String] = [:]
    var used: Set<Int> = []
    for (i, j, _) in edges where assignments[i] == nil && !used.contains(j) {
      assignments[i] = previous[j].id
      used.insert(j)
    }
    return fresh.enumerated().map { i, event in
      AstroEvent(
        id: assignments[i] ?? event.id, instant: event.instant, kind: event.kind,
        bodies: event.bodies,
        longitude: event.longitude, aspectAngle: event.aspectAngle,
        previousSign: event.previousSign, enteredSign: event.enteredSign)
    }
  }
}
