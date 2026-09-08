import Foundation

public enum LeadCategory: String, CaseIterable, Codable, Sendable, Identifiable {
  case moonIngress, planetaryIngress, aspect, station
  public var id: String { rawValue }
  public var name: String {
    switch self {
    case .moonIngress: "Moon ingress"
    case .planetaryIngress: "Other ingresses"
    case .aspect: "Aspects"
    case .station: "Stations"
    }
  }
}

public struct LeadRule: Codable, Sendable, Equatable {
  public let category: LeadCategory
  public let minutes: [Int]
  public init(category: LeadCategory, minutes: [Int]) {
    self.category = category
    self.minutes = Array(Set(minutes)).sorted()
  }
}

public struct QuietHours: Codable, Sendable, Equatable {
  public let enabled: Bool
  public let startMinute: Int
  public let endMinute: Int
  public init(enabled: Bool = false, startMinute: Int = 1320, endMinute: Int = 480) {
    self.enabled = enabled
    self.startMinute = startMinute
    self.endMinute = endMinute
  }
  public func contains(_ date: Date, in zone: TimeZone) -> Bool {
    guard enabled else { return false }
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = zone
    let minute =
      calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
    if startMinute == endMinute { return true }
    return startMinute < endMinute
      ? minute >= startMinute && minute < endMinute : minute >= startMinute || minute < endMinute
  }
}

public enum AlertPreferenceChange: Sendable {
  case enabled(Bool)
  case paused(Bool)
  case sound(Bool)
  case exact(Bool)
  case lunarAspects(Bool)
  case bodies([Body])
  case kinds([EventKind])
  case leads(LeadCategory, [Int])
  case quietHours(QuietHours)
}

public struct AlertPreferences: Codable, Sendable, Equatable {
  public let enabled: Bool
  public let paused: Bool
  public let sound: Bool
  public let exact: Bool
  public let includeLunarAspects: Bool
  public let bodies: [Body]
  public let kinds: [EventKind]
  public let leadRules: [LeadRule]
  public let quietHours: QuietHours
  public static let defaults = AlertPreferences()
  public init(
    enabled: Bool = false, paused: Bool = false, sound: Bool = false, exact: Bool = true,
    includeLunarAspects: Bool = false, bodies: [Body] = Body.allCases,
    kinds: [EventKind] = EventKind.standard,
    leadRules: [LeadRule] = [
      LeadRule(category: .moonIngress, minutes: [30]),
      LeadRule(category: .planetaryIngress, minutes: [1440]),
      LeadRule(category: .aspect, minutes: [60]),
      LeadRule(category: .station, minutes: [1440, 4320]),
    ],
    quietHours: QuietHours = QuietHours()
  ) {
    self.enabled = enabled
    self.paused = paused
    self.sound = sound
    self.exact = exact
    self.includeLunarAspects = includeLunarAspects
    self.bodies = bodies
    self.kinds = kinds
    self.leadRules = leadRules
    self.quietHours = quietHours
  }
  public func updating(_ change: AlertPreferenceChange) -> AlertPreferences {
    var enabled = enabled
    var paused = paused
    var sound = sound
    var exact = exact
    var lunar = includeLunarAspects
    var bodies = bodies
    var kinds = kinds
    var rules = leadRules
    var quiet = quietHours
    switch change {
    case .enabled(let value): enabled = value
    case .paused(let value): paused = value
    case .sound(let value): sound = value
    case .exact(let value): exact = value
    case .lunarAspects(let value): lunar = value
    case .bodies(let value): bodies = Body.allCases.filter { value.contains($0) }
    case .kinds(let value): kinds = EventKind.allCases.filter { value.contains($0) }
    case .leads(let category, let minutes):
      rules.removeAll { $0.category == category }
      rules.append(LeadRule(category: category, minutes: minutes))
    case .quietHours(let value): quiet = value
    }
    return AlertPreferences(
      enabled: enabled, paused: paused, sound: sound, exact: exact,
      includeLunarAspects: lunar, bodies: bodies, kinds: kinds, leadRules: rules, quietHours: quiet)
  }
  public func validate() throws {
    guard (0..<1440).contains(quietHours.startMinute), (0..<1440).contains(quietHours.endMinute),
      leadRules.allSatisfy({
        $0.minutes.count <= 12 && $0.minutes.allSatisfy { (0...129600).contains($0) }
      }),
      Set(leadRules.map(\.category)).count == leadRules.count
    else {
      throw CoreError.invalidArgument(
        "Quiet hours must use valid civil times; choose up to 12 leads per category between 0 and 90 days."
      )
    }
  }
}
