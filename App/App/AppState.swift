import Foundation
import HypergateAstronomyEngine
import HypergateCore
import OSLog
import Observation

@MainActor @Observable
final class AppState {
  static let shared = AppState()
  let provider: any EphemerisProvider
  private let engine: EventEngine
  private let clock: any WallClock
  private let storage: any StateStorage
  let notifications: MacNotificationClient
  let reconciler: NotificationReconciler
  let loginItem = LoginItemService()
  let updates = UpdateService()
  private let logger = Logger(subsystem: "ai.hypergate.HypergateBar", category: "calculation")
  var sky: SkySnapshot?
  var nextMoonIngress: AstroEvent?
  var error: String?
  var calculating = false
  var preferences = AppPreferences()
  var forecast: EventDocument?
  var selectedEvent: AstroEvent?
  var recovery: String?
  var reminderReport: ReconciliationReport?
  var serviceError: String?
  var deliveredTests: [String] = []
  var forecastProgress = "Not calculated"
  var displayBodies = Set(Body.allCases)
  var displayTypes = Set(EventKind.standard)
  var showIntroduction = false
  var dashboardVisible = false
  var lastActive: Date?
  var missedEvents: [AstroEvent] = []
  @ObservationIgnored private var forecastTask: Task<Void, Never>?
  @ObservationIgnored private var boundaryTask: Task<Void, Never>?
  @ObservationIgnored private var persistenceTask: Task<Void, Never>?
  private var preferencesGeneration = 0
  private var generation = 0
  private var launchReceiptWritten = false
  init(
    provider: any EphemerisProvider = AstronomyEngineProvider(),
    clock: any WallClock = SystemWallClock(),
    storage: (any StateStorage)? = nil,
    notifications: MacNotificationClient = MacNotificationClient()
  ) {
    self.provider = provider
    self.clock = clock
    self.engine = EventEngine(provider: provider, clock: clock)
    let directory =
      ProcessInfo.processInfo.environment["HYPERGATE_TEST_DATA"].map { URL(fileURLWithPath: $0) }
      ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("HypergateBar")
    self.storage = storage ?? JSONStateStore(directory: directory)
    self.notifications = notifications
    reconciler = NotificationReconciler(client: notifications)
  }
  func start() async {
    do { if let saved = try await storage.loadPreferences() { preferences = saved } } catch {
      recovery = "Preferences could not be read. Safe defaults restored: \(error)"
    }
    showIntroduction = !preferences.introduced
    do {
      if let cached = try await storage.loadEvents(), cached.provider == provider.metadata,
        cached.query.types == EventKind.allCases,
        cached.coverageEnd > clock.now(), cached.complete
      {
        forecast = cached
        missedEvents = cached.events.filter {
          $0.instant > cached.calculatedAt && $0.instant <= clock.now()
        }
        forecastProgress = "Cached forecast loaded"
      }
    } catch { recovery = "The event cache could not be read; recalculating. \(error)" }
    await refresh()
  }
  func refresh() async {
    generation += 1
    let token = generation
    calculating = true
    defer { if token == generation { calculating = false } }
    do {
      let now = clock.now()
      let positions = try await provider.positions(at: now, bodies: Body.allCases)
      guard token == generation, !Task.isCancelled else { return }
      sky = SkySnapshot(
        provider: provider.metadata, at: now, calculatedAt: clock.now(), positions: positions)
      if !launchReceiptWritten,
        let path = ProcessInfo.processInfo.environment["HYPERGATE_LAUNCH_RECEIPT"], let sky
      {
        launchReceiptWritten = true
        let data = try UTCDate.encoder().encode(sky)
        try await Task.detached { try data.write(to: URL(fileURLWithPath: path), options: .atomic) }
          .value
      }
      let moonQuery = try EventQuery(
        from: now, to: min(now.addingTimeInterval(4 * 86400), provider.metadata.latestExclusive),
        bodies: [.moon], types: [.ingress])
      let ingress = try await engine.events(moonQuery).events.first
      guard token == generation, !Task.isCancelled else { return }
      nextMoonIngress = ingress
      error = nil
      logger.info("Sky and next Moon ingress calculated")
      scheduleBoundary()
      if forecast == nil || (forecast?.coverageEnd.timeIntervalSince(now) ?? 0) < 89 * 86400 {
        extendForecast(from: now)
      }
      await reconcileReminders()
    } catch is CancellationError {
      return
    } catch {
      guard token == generation else { return }
      self.error = String(describing: error)
      logger.error("Calculation failed: \(String(describing: error), privacy: .public)")
    }
  }
  var moon: Position? { sky?.positions.first { $0.body == .moon } }
  var zone: TimeZone { preferences.displayZone.flatMap(TimeZone.init(identifier:)) ?? .current }
  func formatted(_ date: Date) -> String {
    date.formatted(Date.FormatStyle(date: .abbreviated, time: .standard, timeZone: zone))
  }
  var visibleEvents: [AstroEvent] {
    (forecast?.events ?? []).filter {
      $0.instant >= clock.now() && displayTypes.contains($0.kind)
        && $0.bodies.allSatisfy(displayBodies.contains)
    }
  }
  var aspects: [AspectStatus] {
    AspectStatus.current(
      positions: (sky?.positions ?? []).filter { displayBodies.contains($0.body) },
      types: Array(displayTypes), majorOrb: preferences.majorOrb, minorOrb: preferences.minorOrb)
  }
  private func extendForecast(from now: Date) {
    guard forecastTask == nil else { return }
    forecastTask = Task {
      defer { forecastTask = nil }
      do {
        let start = Calendar(identifier: .gregorian).startOfDay(for: now)
        var allEvents: [AstroEvent] = []
        var left = start
        for days in [1, 7, 30, 90] {
          try Task.checkCancellation()
          let right = min(
            start.addingTimeInterval(Double(days) * 86400), provider.metadata.latestExclusive)
          guard right > left else { break }
          forecastProgress = "Calculating \(days)-day forecast…"
          let segment = try await engine.events(
            EventQuery(from: left, to: right, types: EventKind.allCases))
          allEvents += segment.events
          let reconciled = EventIdentity.reconcile(allEvents, previous: forecast?.events ?? [])
          let query = try EventQuery(from: start, to: right, types: EventKind.allCases)
          let document = EventDocument(
            provider: provider.metadata, calculatedAt: clock.now(), query: query, events: reconciled
          )
          // Keep previously calculated longer coverage usable during replenishment.
          if forecast == nil || right >= (forecast?.coverageEnd ?? right) {
            forecast = document
            try await storage.saveEvents(document)
          }
          await reconcileReminders()
          left = right
        }
        forecastProgress = "Forecast calculated"
      } catch is CancellationError {
        forecastProgress = "Forecast paused; calculated coverage remains available"
      } catch { forecastProgress = "Incomplete forecast: \(error)" }
    }
  }
  private func scheduleBoundary() {
    boundaryTask?.cancel()
    guard let next = nextMoonIngress else { return }
    let ingressDelay = max(1, next.instant.timeIntervalSince(clock.now()) + 1)
    let delay = preferences.countdown ? min(ingressDelay, 3600) : ingressDelay
    boundaryTask = Task {
      do {
        try await Task.sleep(for: .seconds(delay))
        await refresh()
      } catch { return }
    }
  }
  func refreshVisible() async {
    guard !calculating, sky == nil || clock.now().timeIntervalSince(sky?.at ?? .distantPast) >= 60
    else { return }
    await refresh()
  }
  func wakeOrClockChanged() async {
    let now = clock.now()
    if let lastActive {
      missedEvents = (forecast?.events ?? []).filter {
        $0.instant > lastActive && $0.instant <= now
      }
    }
    lastActive = now
    loginItem.refresh()
    await refresh()
  }
  func replacePreferences(_ value: AppPreferences) {
    do { try value.validate() } catch {
      serviceError = String(describing: error)
      return
    }
    preferences = value
    preferencesGeneration += 1
    let token = preferencesGeneration
    let preceding = persistenceTask
    persistenceTask = Task {
      await preceding?.value
      guard token == preferencesGeneration else { return }
      do { try await storage.savePreferences(value) } catch {
        serviceError = "Preferences were not saved: \(error)"
      }
      await reconcileReminders()
    }
  }
  func setAlerts(_ change: AlertPreferenceChange) {
    let p = preferences
    replacePreferences(
      AppPreferences(
        alerts: p.alerts.updating(change), displayZone: p.displayZone, labelMode: p.labelMode,
        countdown: p.countdown,
        majorOrb: p.majorOrb, minorOrb: p.minorOrb, stationaryThreshold: p.stationaryThreshold,
        introduced: p.introduced))
  }
  func enableAlerts() async {
    do {
      if try await notifications.requestPermission() {
        setAlerts(.enabled(true))
        serviceError = nil
      } else {
        serviceError =
          "Notifications are denied. Open System Settings → Notifications → HypergateBar to allow them."
      }
    } catch { serviceError = String(describing: error) }
    await reconcileReminders()
  }
  func reconcileReminders() async {
    do {
      let plan = try NotificationPlanner.plan(
        events: forecast?.events ?? [], preferences: preferences.alerts, now: clock.now(),
        deviceTimeZone: .current)
      let report = await reconciler.reconcile(plan)
      reminderReport = report
      deliveredTests = await notifications.deliveredTests()
      try await storage.saveRequests(report.queued)
    } catch { serviceError = "Reminder reconciliation failed: \(error)" }
  }
  func testNotification() async {
    do {
      try await reconciler.testNotification(now: clock.now(), sound: preferences.alerts.sound)
      serviceError = nil
    } catch { serviceError = String(describing: error) }
  }
}
