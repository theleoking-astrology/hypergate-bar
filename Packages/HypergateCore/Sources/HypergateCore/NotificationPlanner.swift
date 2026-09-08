import Foundation

public struct PlannedReminder: Codable, Sendable, Equatable, Identifiable {
  public static let ownedPrefix = "hypergatebar."
  public static let eventPrefix = "hypergatebar.event.v1."
  public let id: String
  public let delivery: Date
  public let event: AstroEvent?
  public let leadMinutes: Int
  public let sound: Bool
  public init(id: String, delivery: Date, event: AstroEvent?, leadMinutes: Int, sound: Bool) {
    self.id = id
    self.delivery = delivery
    self.event = event
    self.leadMinutes = leadMinutes
    self.sound = sound
  }
  public var title: String { event?.title ?? "HypergateBar test notification" }
}

public struct NotificationPlan: Codable, Sendable {
  public let requests: [PlannedReminder]
  public let suppressedByQuietHours: Int
  public let eligibleCount: Int
  public init(requests: [PlannedReminder], suppressedByQuietHours: Int = 0, eligibleCount: Int = 0)
  {
    self.requests = requests
    self.suppressedByQuietHours = suppressedByQuietHours
    self.eligibleCount = eligibleCount
  }
}

public enum NotificationPlanner {
  public static let routineBudget = 44
  public static let totalOwnedBudget = 48
  public static func plan(
    events: [AstroEvent], preferences: AlertPreferences, now: Date, deviceTimeZone: TimeZone
  ) throws -> NotificationPlan {
    try preferences.validate()
    guard preferences.enabled, !preferences.paused else { return NotificationPlan(requests: []) }
    var candidates: [PlannedReminder] = []
    var seen = Set<String>()
    var suppressed = 0
    for event in events {
      guard event.instant > now, preferences.kinds.contains(event.kind),
        event.bodies.allSatisfy({ preferences.bodies.contains($0) })
      else { continue }
      let isAspect = !event.kind.angles.isEmpty
      if isAspect && event.bodies.contains(.moon) && !preferences.includeLunarAspects { continue }
      let category: LeadCategory =
        event.kind.isStation
        ? .station : isAspect ? .aspect : event.bodies == [.moon] ? .moonIngress : .planetaryIngress
      var leads = Set(preferences.leadRules.first { $0.category == category }?.minutes ?? [])
      if preferences.exact { leads.insert(0) }
      for minutes in leads {
        let delivery = Date(
          timeIntervalSince1970: (event.instant.timeIntervalSince1970 - Double(minutes * 60))
            .rounded())
        guard delivery > now.addingTimeInterval(1) else { continue }
        if preferences.quietHours.contains(delivery, in: deviceTimeZone) {
          suppressed += 1
          continue
        }
        let id = PlannedReminder.eventPrefix + event.id + ":lead:\(minutes)"
        guard seen.insert(id).inserted else { continue }
        candidates.append(
          PlannedReminder(
            id: id, delivery: delivery, event: event, leadMinutes: minutes, sound: preferences.sound
          ))
      }
    }
    candidates.sort { $0.delivery == $1.delivery ? $0.id < $1.id : $0.delivery < $1.delivery }
    return NotificationPlan(
      requests: Array(candidates.prefix(routineBudget)), suppressedByQuietHours: suppressed,
      eligibleCount: candidates.count)
  }
}
