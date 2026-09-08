import Foundation

public enum NotificationAuthorization: String, Codable, Sendable {
  case notDetermined, denied, authorized
}

public struct PendingNotification: Sendable {
  public let id: String
  public let request: PlannedReminder?
  public init(id: String, request: PlannedReminder?) {
    self.id = id
    self.request = request
  }
}

public protocol NotificationClient: Sendable {
  func authorization() async -> NotificationAuthorization
  func pending() async throws -> [PendingNotification]
  func add(_ request: PlannedReminder) async throws
  func remove(ids: [String]) async
}

public struct ReconciliationReport: Sendable {
  public let authorization: NotificationAuthorization
  public let queued: [PlannedReminder]
  public let errors: [String]
  public var latestQueuedEvent: Date? { queued.compactMap { $0.event?.instant }.max() }
  public init(authorization: NotificationAuthorization, queued: [PlannedReminder], errors: [String])
  {
    self.authorization = authorization
    self.queued = queued
    self.errors = errors
  }
}

/// A single draining worker owns all routine scheduling. New generations replace
/// the desired plan, and every suspension checks that generation before continuing.
public actor NotificationReconciler {
  private let client: any NotificationClient
  private var revision = 0
  private var latest = NotificationPlan(requests: [])
  private var running = false
  private var testing = false
  private var waiters: [CheckedContinuation<ReconciliationReport, Never>] = []
  public init(client: any NotificationClient) { self.client = client }
  public func reconcile(_ plan: NotificationPlan) async -> ReconciliationReport {
    revision += 1
    latest = plan
    return await withCheckedContinuation { continuation in
      waiters.append(continuation)
      if !running {
        running = true
        Task { await self.drain() }
      }
    }
  }
  private func drain() async {
    while true {
      let token = revision
      let plan = latest
      let permission = await client.authorization()
      if token != revision { continue }
      var errors: [String] = []
      do {
        let pending = try await client.pending()
        if token != revision { continue }
        let desired =
          permission == .authorized
          ? Array(plan.requests.prefix(NotificationPlanner.routineBudget)) : []
        guard Set(desired.map(\.id)).count == desired.count,
          desired.allSatisfy({ $0.id.hasPrefix(PlannedReminder.eventPrefix) })
        else {
          throw CoreError.invalidArgument(
            "Invalid notification plan ownership or duplicate identifiers.")
        }
        let wanted = Dictionary(uniqueKeysWithValues: desired.map { ($0.id, $0) })
        let obsolete = pending.filter {
          $0.id.hasPrefix(PlannedReminder.eventPrefix)
            && (wanted[$0.id] == nil || wanted[$0.id] != $0.request)
        }.map(\.id)
        await client.remove(ids: obsolete)
        if token != revision { continue }
        var ownedCount = pending.filter {
          $0.id.hasPrefix(PlannedReminder.ownedPrefix) && !obsolete.contains($0.id)
        }.count
        for request in desired {
          if pending.contains(where: { $0.id == request.id && $0.request == request }) { continue }
          if token != revision { break }
          guard ownedCount < NotificationPlanner.totalOwnedBudget else {
            errors.append("Owned notification queue is full.")
            break
          }
          do {
            try await client.add(request)
            ownedCount += 1
            if token != revision {
              await client.remove(ids: [request.id])
              break
            }
          } catch { errors.append(String(describing: error)) }
        }
        if token != revision { continue }
      } catch { errors.append(String(describing: error)) }
      var queued: [PlannedReminder] = []
      do {
        queued = try await client.pending().compactMap(\.request).filter {
          $0.id.hasPrefix(PlannedReminder.eventPrefix)
        }.sorted { $0.delivery < $1.delivery }
      } catch { errors.append("Pending-request readback failed: \(error)") }
      if token != revision { continue }
      let report = ReconciliationReport(authorization: permission, queued: queued, errors: errors)
      let callbacks = waiters
      waiters.removeAll()
      running = false
      for callback in callbacks { callback.resume(returning: report) }
      return
    }
  }
  public func testNotification(now: Date, sound: Bool) async throws {
    guard !testing else {
      throw CoreError.invalidArgument("A test notification is already being scheduled.")
    }
    testing = true
    defer { testing = false }
    guard await client.authorization() == .authorized else {
      throw CoreError.invalidArgument("Enable notification permission before testing delivery.")
    }
    let pending = try await client.pending()
    let specials = pending.filter {
      $0.id.hasPrefix(PlannedReminder.ownedPrefix) && !$0.id.hasPrefix(PlannedReminder.eventPrefix)
    }
    guard specials.count < 4,
      pending.filter({ $0.id.hasPrefix(PlannedReminder.ownedPrefix) }).count < 48
    else {
      throw CoreError.invalidArgument(
        "Test-notification reserve is full. Wait for an existing test to deliver.")
    }
    try await client.add(
      PlannedReminder(
        id: "hypergatebar.test." + UUID().uuidString,
        delivery: now.addingTimeInterval(5), event: nil, leadMinutes: 0, sound: sound))
  }
}
