import Foundation
import Testing

@testable import HypergateCore

private func reminderEvent(
  _ id: String, _ date: Date, body: Body = .moon, kind: EventKind = .ingress
) -> AstroEvent {
  AstroEvent(id: id, instant: date, kind: kind, bodies: [body], enteredSign: .aries)
}

@Test func plannerDeduplicatesZeroLeadAndBoundsQueue() throws {
  let now = try UTCDate.parse("2026-09-08T00:00:00Z")
  var preferences = AlertPreferences.defaults.updating(.enabled(true))
  preferences = preferences.updating(.leads(.moonIngress, [0, 30, 30]))
  let events = (1...80).map { reminderEvent("e\($0)", now.addingTimeInterval(Double($0) * 3600)) }
  let plan = try NotificationPlanner.plan(
    events: events, preferences: preferences, now: now, deviceTimeZone: .gmt)
  #expect(plan.requests.count == 44)
  #expect(Set(plan.requests.map(\.id)).count == 44)
  #expect(plan.requests.filter { $0.event?.id == "e1" }.count == 2)
}

@Test func quietHoursUseDeviceZoneAcrossMidnightAndDST() throws {
  let zone = try #require(TimeZone(identifier: "America/Los_Angeles"))
  let quiet = QuietHours(enabled: true, startMinute: 22 * 60, endMinute: 8 * 60)
  for text in ["2026-11-01T08:30:00Z", "2026-11-01T09:30:00Z", "2026-03-08T10:30:00Z"] {
    #expect(quiet.contains(try UTCDate.parse(text), in: zone))
  }
  #expect(!quiet.contains(try UTCDate.parse("2026-11-01T17:00:00Z"), in: zone))
}

@Test func pausedDeniedAndSleepGapNeverCreateCatchup() async throws {
  let now = try UTCDate.parse("2026-09-08T12:00:00Z")
  let preferences = AlertPreferences.defaults.updating(.enabled(true))
  let event = reminderEvent("past", now.addingTimeInterval(-300))
  #expect(
    try NotificationPlanner.plan(
      events: [event], preferences: preferences, now: now, deviceTimeZone: .gmt
    ).requests.isEmpty)
  let client = FakeNotificationClient(permission: .denied)
  let reconciler = NotificationReconciler(client: client)
  let future = reminderEvent("future", now.addingTimeInterval(7200))
  let plan = try NotificationPlanner.plan(
    events: [future], preferences: preferences, now: now, deviceTimeZone: .gmt)
  let report = await reconciler.reconcile(plan)
  #expect(report.authorization == .denied)
  #expect(report.queued.isEmpty)
  #expect(
    try NotificationPlanner.plan(
      events: [future], preferences: preferences.updating(.paused(true)), now: now,
      deviceTimeZone: .gmt
    ).requests.isEmpty)
}

@Test func reconciliationIsIdempotentAndPreservesForeignRequests() async throws {
  let now = try UTCDate.parse("2026-09-08T12:00:00Z")
  let plan = try NotificationPlanner.plan(
    events: [reminderEvent("future", now.addingTimeInterval(7200))],
    preferences: .defaults.updating(.enabled(true)), now: now, deviceTimeZone: .gmt)
  let client = FakeNotificationClient(permission: .authorized)
  let reconciler = NotificationReconciler(client: client)
  _ = await reconciler.reconcile(plan)
  let calls = await client.addCount
  let report = await reconciler.reconcile(plan)
  #expect(await client.addCount == calls)
  #expect(report.queued.count == 2)
  #expect(await client.foreignPreserved)
}

@Test func partialSchedulingFailureIsReportedAndReadBack() async throws {
  let now = try UTCDate.parse("2026-09-08T12:00:00Z")
  let plan = try NotificationPlanner.plan(
    events: [reminderEvent("future", now.addingTimeInterval(7200))],
    preferences: .defaults.updating(.enabled(true)), now: now, deviceTimeZone: .gmt)
  let client = FakeNotificationClient(permission: .authorized, failFirst: true)
  let report = await NotificationReconciler(client: client).reconcile(plan)
  #expect(report.errors.count == 1)
  #expect(report.queued.count == 1)
}

actor FakeNotificationClient: NotificationClient {
  let permission: NotificationAuthorization
  var items: [PendingNotification] = [PendingNotification(id: "foreign", request: nil)]
  var addCount = 0
  var failFirst: Bool
  init(permission: NotificationAuthorization, failFirst: Bool = false) {
    self.permission = permission
    self.failFirst = failFirst
  }
  func authorization() async -> NotificationAuthorization { permission }
  func pending() async throws -> [PendingNotification] { items }
  func add(_ request: PlannedReminder) async throws {
    addCount += 1
    if failFirst {
      failFirst = false
      throw CoreError.provider("Synthetic scheduling failure")
    }
    items.removeAll { $0.id == request.id }
    items.append(PendingNotification(id: request.id, request: request))
  }
  func remove(ids: [String]) async { items.removeAll { ids.contains($0.id) } }
  var foreignPreserved: Bool { items.contains { $0.id == "foreign" } }
}

@Test func newerSettingsWinAfterSuspendedScheduling() async throws {
  let now = try UTCDate.parse("2026-09-08T12:00:00Z")
  let plan = try NotificationPlanner.plan(
    events: [reminderEvent("future", now.addingTimeInterval(7200))],
    preferences: .defaults.updating(.enabled(true)), now: now, deviceTimeZone: .gmt)
  let client = SuspendedNotificationClient()
  let reconciler = NotificationReconciler(client: client)
  let first = Task { await reconciler.reconcile(plan) }
  await client.waitForAdd()
  let latest = Task { await reconciler.reconcile(NotificationPlan(requests: [])) }
  // The latest reconcile must enter its actor before the old add is released.
  await Task.yield()
  await client.release()
  _ = await first.value
  let report = await latest.value
  #expect(report.queued.isEmpty)
  #expect(await client.pending().isEmpty)
}

private actor SuspendedNotificationClient: NotificationClient {
  var items: [PendingNotification] = []
  var reached = false
  var waiting: CheckedContinuation<Void, Never>?
  var blocker: CheckedContinuation<Void, Never>?
  func authorization() async -> NotificationAuthorization { .authorized }
  func pending() async -> [PendingNotification] { items }
  func add(_ request: PlannedReminder) async throws {
    if !reached {
      reached = true
      await withCheckedContinuation { continuation in
        blocker = continuation
        waiting?.resume()
        waiting = nil
      }
    }
    items.append(PendingNotification(id: request.id, request: request))
  }
  func waitForAdd() async {
    if reached { return }
    await withCheckedContinuation { waiting = $0 }
  }
  func release() {
    blocker?.resume()
    blocker = nil
  }
  func remove(ids: [String]) async { items.removeAll { ids.contains($0.id) } }
}
