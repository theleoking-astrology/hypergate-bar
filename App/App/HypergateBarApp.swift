import AppKit
import HypergateCore
import SwiftUI
import UserNotifications

@main
struct HypergateBarApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
  @State private var state = AppState.shared
  var body: some Scene {
    MenuBarExtra {
      MenuBarView(state: state)
    } label: {
      Text(menuLabel)
        .accessibilityLabel(
          state.moon.map { "Moon in \($0.sign.name)" } ?? "HypergateBar calculating")
    }.menuBarExtraStyle(.window)
    Settings { SettingsView(state: state) }
  }
  private var menuLabel: String {
    guard state.preferences.labelMode != .iconOnly else { return "☽" }
    guard let moon = state.moon else { return "☽ …" }
    let label =
      state.preferences.labelMode == .compact ? "☽ \(moon.sign.symbol)" : "☽ \(moon.sign.name)"
    guard state.preferences.countdown, let next = state.nextMoonIngress else { return label }
    let hours = max(0, Int(next.instant.timeIntervalSinceNow / 3600))
    return label + " \(hours)h"
  }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
  private static weak var current: AppDelegate?
  private var dashboard: NSWindowController?
  private let navigation = NotificationNavigation()
  private var observations: [NSObjectProtocol] = []
  func applicationDidFinishLaunching(_ notification: Notification) {
    Self.current = self
    // Scoped visual-validation arguments never modify the user's global theme.
    if CommandLine.arguments.contains("--dark-appearance") {
      NSApp.appearance = NSAppearance(named: .darkAqua)
    }
    if CommandLine.arguments.contains("--light-appearance") {
      NSApp.appearance = NSAppearance(named: .aqua)
    }
    UNUserNotificationCenter.current().delegate = navigation
    Task {
      await AppState.shared.start()
      if AppState.shared.showIntroduction { showDashboard() }
    }
    for name in [NSWorkspace.didWakeNotification] {
      observations.append(
        NSWorkspace.shared.notificationCenter.addObserver(forName: name, object: nil, queue: .main)
        { _ in
          Task { @MainActor in await AppState.shared.wakeOrClockChanged() }
        })
    }
    for name in [
      NSNotification.Name.NSSystemClockDidChange, NSNotification.Name.NSSystemTimeZoneDidChange,
    ] {
      observations.append(
        NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { _ in
          Task { @MainActor in await AppState.shared.wakeOrClockChanged() }
        })
    }
    if CommandLine.arguments.contains("--dashboard") { showDashboard() }
  }
  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
  func applicationDidBecomeActive(_ notification: Notification) {
    Task { await AppState.shared.wakeOrClockChanged() }
  }
  func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool
  {
    showDashboard()
    return true
  }
  func showDashboard() {
    if dashboard == nil {
      let controller = NSHostingController(rootView: DashboardView(state: .shared))
      let window = NSWindow(contentViewController: controller)
      window.title = "HypergateBar"
      window.setContentSize(NSSize(width: 920, height: 650))
      window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
      window.isReleasedWhenClosed = false
      window.delegate = self
      window.center()
      dashboard = NSWindowController(window: window)
    }
    dashboard?.showWindow(nil)
    AppState.shared.dashboardVisible = true
    NSApp.activate(ignoringOtherApps: true)
  }
  static func openDashboard() {
    current?.showDashboard()
  }
  func windowWillClose(_ notification: Notification) { AppState.shared.dashboardVisible = false }
}
