import HypergateCore
import SwiftUI

struct MenuBarView: View {
  @Bindable var state: AppState
  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack {
        Label("HypergateBar", systemImage: "moon.stars")
          .font(.headline)
        Spacer()
        if state.calculating { ProgressView().controlSize(.small) }
      }
      if let moon = state.moon {
        Text("Moon in \(moon.sign.name)").font(.title2.weight(.semibold))
        Text("\(moon.degreeText) · \(state.sky?.moonPhase ?? "Phase unavailable")")
          .foregroundStyle(.secondary)
      } else {
        Text("Calculating the sky…").foregroundStyle(.secondary)
      }
      if let event = state.nextMoonIngress {
        VStack(alignment: .leading, spacing: 4) {
          Text("NEXT MOON INGRESS").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
          Text(event.title)
          Text(state.formatted(event.instant))
            .foregroundStyle(.secondary)
        }
      }
      if let positions = state.sky?.positions {
        let retrogrades = positions.filter {
          $0.motion(stationaryThreshold: state.preferences.stationaryThreshold) == "Retrograde"
        }
        Text(
          "Retrograde: "
            + (retrogrades.isEmpty
              ? "None" : retrogrades.map { $0.body.name }.joined(separator: ", "))
        ).font(.caption)
      }
      if !state.visibleEvents.isEmpty {
        Text("NEXT SELECTED EVENTS").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
        ForEach(Array(state.visibleEvents.prefix(3))) { EventRow(event: $0, state: state) }
      }
      if let error = state.error {
        Text("Unavailable / stale: \(error)").font(.caption).foregroundStyle(.red)
      }
      Divider()
      Button("Open Dashboard", action: AppDelegate.openDashboard).keyboardShortcut("d")
      SettingsLink { Text("Settings…") }.keyboardShortcut(",")
      Button(state.preferences.alerts.paused ? "Resume Alerts" : "Pause Alerts") {
        state.setAlerts(.paused(!state.preferences.alerts.paused))
      }
      Button("Refresh") { Task { await state.refresh() } }
      Divider()
      Button("Quit HypergateBar") { NSApplication.shared.terminate(nil) }.keyboardShortcut("q")
    }
    .padding(20)
    .frame(width: 340)
    .tint(.purple)
    .sheet(item: $state.selectedEvent) { EventDetailView(event: $0, state: state) }
    .task {
      while !Task.isCancelled {
        await state.refreshVisible()
        do { try await Task.sleep(for: .seconds(60)) } catch { return }
      }
    }
  }
}
