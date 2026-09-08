import AppKit
import SwiftUI

@main
struct HypergateBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var state = AppState.shared
    var body: some Scene {
        MenuBarExtra {
            MenuBarView(state: state)
        } label: {
            Text(state.moon.map { "☽ \($0.sign.symbol)" } ?? "☽ …")
                .accessibilityLabel(state.moon.map { "Moon in \($0.sign.name)" } ?? "HypergateBar calculating")
        }.menuBarExtraStyle(.window)
        Settings { SettingsView(state: state) }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private static weak var current: AppDelegate?
    private var dashboard: NSWindowController?
    func applicationDidFinishLaunching(_ notification: Notification) {
        Self.current = self
        Task { await AppState.shared.refresh() }
        if CommandLine.arguments.contains("--dashboard") { showDashboard() }
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
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
            window.center()
            dashboard = NSWindowController(window: window)
        }
        dashboard?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    static func openDashboard() {
        current?.showDashboard()
    }
}
