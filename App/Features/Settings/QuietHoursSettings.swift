import HypergateCore
import SwiftUI

struct QuietHoursSettings: View {
  let state: AppState
  var body: some View {
    Section("Quiet hours — device local time") {
      Toggle(
        "Suppress reminders during quiet hours",
        isOn: Binding(
          get: { state.preferences.alerts.quietHours.enabled }, set: { update(enabled: $0) }))
      Picker(
        "Start",
        selection: Binding(
          get: { state.preferences.alerts.quietHours.startMinute }, set: { update(start: $0) })
      ) {
        ForEach(0..<24) { hour in Text(String(format: "%02d:00", hour)).tag(hour * 60) }
      }
      Picker(
        "End",
        selection: Binding(
          get: { state.preferences.alerts.quietHours.endMinute }, set: { update(end: $0) })
      ) {
        ForEach(0..<24) { hour in Text(String(format: "%02d:00", hour)).tag(hour * 60) }
      }
      Text(
        "Quiet hours use \(TimeZone.current.identifier), even when the display zone differs. Suppressed events stay visible in the app and are not delivered late. Equal start and end suppress all day."
      ).font(.caption).foregroundStyle(.secondary)
    }
  }
  private func update(enabled: Bool? = nil, start: Int? = nil, end: Int? = nil) {
    let quiet = state.preferences.alerts.quietHours
    state.setAlerts(
      .quietHours(
        QuietHours(
          enabled: enabled ?? quiet.enabled, startMinute: start ?? quiet.startMinute,
          endMinute: end ?? quiet.endMinute)))
  }
}
