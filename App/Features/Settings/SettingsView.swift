import HypergateCore
import SwiftUI

struct SettingsView: View {
  @Bindable var state: AppState
  @State private var displayZone = ""
  @State private var leadText: [LeadCategory: String] = [:]
  var body: some View {
    TabView {
      Form {
        Section("Menu bar") {
          Picker(
            "Label",
            selection: Binding(get: { state.preferences.labelMode }, set: { update(label: $0) })
          ) {
            Text("Moon and sign").tag(MenuLabelMode.standard)
            Text("Compact symbols").tag(MenuLabelMode.compact)
            Text("Icon only").tag(MenuLabelMode.iconOnly)
          }
          Toggle(
            "Show next-ingress countdown",
            isOn: Binding(get: { state.preferences.countdown }, set: { update(countdown: $0) }))
          Text(
            "Closing Dashboard keeps the menu-bar app running. Reopen HypergateBar from Finder or Spotlight to restore access after removing its menu item."
          ).font(.caption).foregroundStyle(.secondary)
        }
        Section("Time and calculations") {
          TextField("IANA display zone (blank follows device)", text: $displayZone)
          Button("Apply display zone") { update(zone: displayZone) }
          Text("Current display zone: \(state.zone.identifier)").font(.caption)
          numberField("Major aspect orb (degrees)", value: state.preferences.majorOrb) {
            update(majorOrb: $0)
          }
          numberField("Minor aspect orb (degrees)", value: state.preferences.minorOrb) {
            update(minorOrb: $0)
          }
          numberField(
            "Stationary display threshold (degrees/day)",
            value: state.preferences.stationaryThreshold
          ) { update(stationary: $0) }
          Text("The display threshold does not change exact station calculations.").font(.caption)
            .foregroundStyle(.secondary)
        }
        Section("Launch at login") {
          Toggle(
            "Launch HypergateBar at login",
            isOn: Binding(get: { state.loginItem.enabled }, set: { state.loginItem.setEnabled($0) })
          )
          Text(state.loginItem.statusText).font(.caption)
          if let error = state.loginItem.error { Text(error).foregroundStyle(.red) }
        }
        if let error = state.serviceError { Text(error).foregroundStyle(.red) }
      }.formStyle(.grouped).tabItem { Label("General", systemImage: "gearshape") }
      Form {
        Section("Local notifications") {
          Text("Permission: \(state.reminderReport?.authorization.rawValue ?? "Checking…")")
          if state.preferences.alerts.enabled {
            Button("Disable alerts") { state.setAlerts(.enabled(false)) }
          } else {
            Button("Enable Alerts…") { Task { await state.enableAlerts() } }
              .accessibilityIdentifier("enable-alerts")
          }
          Toggle("Pause alerts", isOn: alertBinding(\.paused, AlertPreferenceChange.paused))
          Toggle(
            "Play notification sound", isOn: alertBinding(\.sound, AlertPreferenceChange.sound))
          Toggle(
            "Include exact-event alerts", isOn: alertBinding(\.exact, AlertPreferenceChange.exact))
          Toggle(
            "Include lunar aspects",
            isOn: alertBinding(\.includeLunarAspects, AlertPreferenceChange.lunarAspects))
          Button("Send clearly labeled test notification") {
            Task { await state.testNotification() }
          }
          Button("Read delivery status from macOS") { Task { await state.reconcileReminders() } }
          ForEach(state.deliveredTests, id: \.self) { Text($0).font(.caption) }
          Text(
            "If denied, allow HypergateBar in System Settings → Notifications. Test delivery is scheduled five seconds ahead. Sleep, Focus, and shutdown can delay or prevent banners."
          ).font(.caption).foregroundStyle(.secondary)
        }
        Section("Event types") {
          ForEach(EventKind.allCases) { kind in
            Toggle(
              kind.name,
              isOn: Binding(
                get: { state.preferences.alerts.kinds.contains(kind) },
                set: { value in
                  var kinds = state.preferences.alerts.kinds
                  if value { kinds.append(kind) } else { kinds.removeAll { $0 == kind } }
                  state.setAlerts(.kinds(kinds))
                }))
          }
        }
        Section("Bodies — both bodies must be selected for an aspect") {
          ForEach(HypergateCore.Body.allCases) { body in
            Toggle(
              body.name,
              isOn: Binding(
                get: { state.preferences.alerts.bodies.contains(body) },
                set: { value in
                  var bodies = state.preferences.alerts.bodies
                  if value { bodies.append(body) } else { bodies.removeAll { $0 == body } }
                  state.setAlerts(.bodies(bodies))
                }))
          }
        }
        Section("Lead times in minutes, separated by commas") {
          ForEach(LeadCategory.allCases) { category in
            TextField(
              category.name,
              text: Binding(get: { leadText[category] ?? "" }, set: { leadText[category] = $0 }))
          }
          Button("Apply lead times") { applyLeads() }
          Text(
            "Blank disables leads for that category. Exact alerts remain separate; coincident deliveries are deduplicated."
          ).font(.caption).foregroundStyle(.secondary)
        }
        QuietHoursSettings(state: state)
        if let report = state.reminderReport {
          Section("Actual queued coverage") {
            Text(
              "\(report.queued.count) ordinary requests; budget 44, plus four reserved test requests."
            )
            Text(
              report.latestQueuedEvent.map { "Last covered event: \(state.formatted($0))" }
                ?? "No event is currently covered.")
            Text(
              "The app must run again to replenish its rolling queue. A 90-day forecast does not imply 90-day reminder coverage."
            ).font(.caption).foregroundStyle(.secondary)
            ForEach(report.errors, id: \.self) { Text($0).foregroundStyle(.red) }
          }
        }
        if let error = state.serviceError { Text(error).foregroundStyle(.red) }
      }.formStyle(.grouped).tabItem { Label("Alerts", systemImage: "bell") }
      Form {
        Section("HypergateBar · 0.1.0 unreleased") {
          Text("Hypergate AI Open Source")
          Text(
            "Offline tropical, geocentric astrology. Original source is MIT licensed. Astronomy Engine notices are included with the source."
          )
          Link(
            "Source, accuracy matrix, and documentation",
            destination: URL(string: "https://github.com/theleoking-astrology/hypergate-bar")
              ?? URL(fileURLWithPath: "/"))
          Text(
            "Core calculations and reminders make no network requests. Optional publisher-configured updates are separate."
          ).foregroundStyle(.secondary)
          Text(state.updates.status)
          Button("Check for Updates…") { state.updates.check() }.disabled(!state.updates.enabled)
        }
      }
      .formStyle(.grouped).tabItem { Label("About", systemImage: "info.circle") }
    }.padding(12).frame(width: 620, height: 640)
      .onAppear {
        displayZone = state.preferences.displayZone ?? ""
        for rule in state.preferences.alerts.leadRules {
          leadText[rule.category] = rule.minutes.map(String.init).joined(separator: ", ")
        }
        state.loginItem.refresh()
        Task { await state.reconcileReminders() }
      }
  }
  private func alertBinding(
    _ key: KeyPath<AlertPreferences, Bool>, _ change: @escaping (Bool) -> AlertPreferenceChange
  ) -> Binding<Bool> {
    Binding(get: { state.preferences.alerts[keyPath: key] }, set: { state.setAlerts(change($0)) })
  }
  private func update(
    zone: String? = nil, label: MenuLabelMode? = nil, countdown: Bool? = nil,
    majorOrb: Double? = nil, minorOrb: Double? = nil, stationary: Double? = nil
  ) {
    let p = state.preferences
    state.replacePreferences(
      AppPreferences(
        alerts: p.alerts, displayZone: zone.map { $0.isEmpty ? nil : $0 } ?? p.displayZone,
        labelMode: label ?? p.labelMode, countdown: countdown ?? p.countdown,
        majorOrb: majorOrb ?? p.majorOrb, minorOrb: minorOrb ?? p.minorOrb,
        stationaryThreshold: stationary ?? p.stationaryThreshold, introduced: p.introduced))
  }
  private func numberField(_ title: String, value: Double, set: @escaping (Double) -> Void)
    -> some View
  {
    TextField(title, value: Binding(get: { value }, set: set), format: .number)
  }
  private func applyLeads() {
    var preferences = state.preferences.alerts
    for category in LeadCategory.allCases {
      let text = (leadText[category] ?? "").trimmingCharacters(in: .whitespaces)
      let parts =
        text.isEmpty
        ? []
        : text.split(separator: ",", omittingEmptySubsequences: false).map {
          $0.trimmingCharacters(in: .whitespaces)
        }
      let minutes = parts.compactMap(Int.init)
      guard parts.count == minutes.count else {
        state.serviceError = "Lead times must be whole minutes separated by commas."
        return
      }
      preferences = preferences.updating(.leads(category, minutes))
    }
    do { try preferences.validate() } catch {
      state.serviceError = String(describing: error)
      return
    }
    for rule in preferences.leadRules { state.setAlerts(.leads(rule.category, rule.minutes)) }
    state.serviceError = nil
  }
}
