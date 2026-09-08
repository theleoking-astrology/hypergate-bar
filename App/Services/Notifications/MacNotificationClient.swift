import Foundation
import HypergateCore
@preconcurrency import UserNotifications

actor MacNotificationClient: NotificationClient {
  private let center = UNUserNotificationCenter.current()
  func authorization() async -> NotificationAuthorization {
    switch await center.notificationSettings().authorizationStatus {
    case .authorized, .provisional, .ephemeral: .authorized
    case .denied: .denied
    default: .notDetermined
    }
  }
  func requestPermission() async throws -> Bool {
    try await center.requestAuthorization(options: [.alert, .sound])
  }
  func deliveredTests() async -> [String] {
    await center.deliveredNotifications().filter {
      $0.request.identifier.hasPrefix("hypergatebar.test.")
    }
    .map { "\($0.request.content.title) · macOS delivered \(UTCDate.string($0.date))" }
  }
  func pending() async throws -> [PendingNotification] {
    await center.pendingNotificationRequests().map { request in
      let payload = request.content.userInfo["reminder"] as? Data
      let decoded = payload.flatMap {
        try? UTCDate.decoder().decode(PlannedReminder.self, from: $0)
      }
      return PendingNotification(id: request.identifier, request: decoded)
    }
  }
  func add(_ request: PlannedReminder) async throws {
    let content = UNMutableNotificationContent()
    content.title = request.title
    content.body =
      request.event.map { event in
        request.leadMinutes == 0
          ? "Calculated event time: \(UTCDate.string(event.instant)). Delivery may be delayed by macOS."
          : "In \(request.leadMinutes) minutes · \(UTCDate.string(event.instant))"
      } ?? "This is a test of HypergateBar local notifications. It is not an astronomical event."
    content.userInfo = ["reminder": try UTCDate.encoder().encode(request)]
    if request.sound { content.sound = .default }
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = .gmt
    var components = calendar.dateComponents(
      [.year, .month, .day, .hour, .minute, .second], from: request.delivery)
    components.calendar = calendar
    components.timeZone = .gmt
    let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
    try await center.add(
      UNNotificationRequest(identifier: request.id, content: content, trigger: trigger))
  }
  func remove(ids: [String]) async {
    center.removePendingNotificationRequests(withIdentifiers: ids)
  }
}

final class NotificationNavigation: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable
{
  func userNotificationCenter(
    _ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let data = response.notification.request.content.userInfo["reminder"] as? Data
    let reminder = data.flatMap { try? UTCDate.decoder().decode(PlannedReminder.self, from: $0) }
    Task { @MainActor in
      AppState.shared.selectedEvent = reminder?.event
      AppDelegate.openDashboard()
    }
    completionHandler()
  }
  func userNotificationCenter(
    _ center: UNUserNotificationCenter, willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    completionHandler([.banner, .list, .sound])
  }
}
