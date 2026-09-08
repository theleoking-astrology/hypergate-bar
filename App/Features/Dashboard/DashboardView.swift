import HypergateCore
import SwiftUI

struct DashboardView: View {
  @Bindable var state: AppState
  @State private var section = "Today"
  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      HStack {
        VStack(alignment: .leading, spacing: 5) {
          Text(section == "Upcoming" ? "What’s ahead." : "The sky, right now.").font(
            .largeTitle.weight(.semibold))
          Text("HYPERGATEBAR · HYPERGATE AI OPEN SOURCE").font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
        }
        Spacer()
        if state.calculating { ProgressView().controlSize(.small) }
        Button("Refresh", systemImage: "arrow.clockwise") { Task { await state.refresh() } }
        Button("Export JSON", systemImage: "square.and.arrow.up") {
          if let document = state.forecast {
            do { try EventExport.save(document) } catch {
              state.serviceError = String(describing: error)
            }
          }
        }.disabled(state.forecast == nil)
      }
      Picker("Dashboard section", selection: $section) {
        ForEach(["Today", "Upcoming", "Planets"], id: \.self) { Text($0) }
      }.pickerStyle(.segmented)
      if let error = state.error { Text("Unavailable / stale: \(error)").foregroundStyle(.red) }
      if let recovery = state.recovery { Text(recovery).font(.caption).foregroundStyle(.orange) }
      if let error = state.serviceError { Text(error).font(.caption).foregroundStyle(.red) }
      if let sky = state.sky {
        if section == "Planets" {
          PlanetTable(positions: sky.positions, state: state)
        } else {
          ScrollView {
            VStack(alignment: .leading, spacing: 18) {
              if section == "Today" {
                if let moon = state.moon {
                  VStack(alignment: .leading, spacing: 6) {
                    Text("Moon in \(moon.sign.name)").font(.title.bold())
                    Text("\(moon.degreeText) · \(sky.moonPhase ?? "Phase unavailable")")
                      .foregroundStyle(.secondary)
                  }.padding(.vertical, 8)
                }
                if let ingress = state.nextMoonIngress { EventRow(event: ingress, state: state) }
                Divider()
                Text("Current aspects").font(.headline)
                ForEach(state.aspects) { aspect in
                  LabeledContent(
                    "\(aspect.bodies.map(\.name).joined(separator: " · ")) · \(aspect.kind.name)",
                    value:
                      "\(aspect.orb.formatted(.number.precision(.fractionLength(2))))° / \(aspect.allowedOrb.formatted())° · \(aspect.trend.rawValue)"
                  )
                }
                if state.aspects.isEmpty {
                  Text("No selected aspect is within its configured orb.").foregroundStyle(
                    .secondary)
                }
                Text("Next selected events").font(.headline)
                ForEach(Array(state.visibleEvents.prefix(5))) { EventRow(event: $0, state: state) }
              } else {
                EventFilters(state: state)
                LazyVStack(alignment: .leading, spacing: 6) {
                  ForEach(state.visibleEvents) { event in
                    EventRow(event: event, state: state)
                    Divider()
                  }
                }
                if state.visibleEvents.isEmpty {
                  Text("No matching event within this calculated window.").foregroundStyle(
                    .secondary)
                }
              }
              if !state.missedEvents.isEmpty {
                Text("Events while you were away").font(.headline)
                ForEach(state.missedEvents) { EventRow(event: $0, state: state) }
              }
            }.frame(maxWidth: .infinity, alignment: .leading)
          }
        }
        Divider()
        VStack(alignment: .leading, spacing: 4) {
          Text(
            "Calculated \(state.formatted(sky.calculatedAt)) · \(state.zone.identifier) · Offline")
          Text(
            state.forecast.map {
              "Forecast through \(state.formatted($0.coverageEnd)) · \(state.forecastProgress)"
            } ?? state.forecastProgress)
          if let report = state.reminderReport {
            Text(
              "\(report.queued.count) reminders queued"
                + (report.latestQueuedEvent.map { " · Last covered event \(state.formatted($0))" }
                  ?? " · Alerts have no queued coverage"))
            ForEach(report.errors, id: \.self) { Text($0).foregroundStyle(.red) }
          }
        }.font(.caption).foregroundStyle(.secondary)
      } else {
        ProgressView("Calculating planetary positions…").frame(
          maxWidth: .infinity, maxHeight: .infinity)
      }
    }
    .padding(28)
    .frame(minWidth: 750, minHeight: 520)
    .tint(.purple)
    .sheet(item: $state.selectedEvent) { EventDetailView(event: $0, state: state) }
    .sheet(isPresented: $state.showIntroduction) { IntroductionView(state: state) }
    .task(id: state.dashboardVisible) {
      guard state.dashboardVisible else { return }
      while !Task.isCancelled {
        await state.refreshVisible()
        do { try await Task.sleep(for: .seconds(60)) } catch { return }
      }
    }
  }
}

struct PlanetTable: View {
  let positions: [Position]
  let state: AppState
  var body: some View {
    Table(positions) {
      TableColumn("Planet") { position in
        HStack {
          Text(position.body.symbol).font(.title2).accessibilityHidden(true)
          Text(position.body.name)
        }
      }
      TableColumn("Sign") { Text($0.sign.name) }
      TableColumn("Position") { Text($0.degreeText).monospacedDigit() }
      TableColumn("Motion") {
        Text($0.motion(stationaryThreshold: state.preferences.stationaryThreshold))
      }
      TableColumn("Degrees/day") {
        Text($0.velocity.formatted(.number.precision(.fractionLength(4)))).monospacedDigit()
      }
    }
  }
}

struct EventFilters: View {
  @Bindable var state: AppState
  var body: some View {
    HStack {
      Menu("Event types (\(state.displayTypes.count))") {
        ForEach(EventKind.allCases) { kind in
          Toggle(
            kind.name,
            isOn: Binding(
              get: { state.displayTypes.contains(kind) },
              set: {
                if $0 { state.displayTypes.insert(kind) } else { state.displayTypes.remove(kind) }
              }))
        }
      }
      Menu("Bodies (\(state.displayBodies.count))") {
        ForEach(HypergateCore.Body.allCases) { body in
          Toggle(
            body.name,
            isOn: Binding(
              get: { state.displayBodies.contains(body) },
              set: {
                if $0 { state.displayBodies.insert(body) } else { state.displayBodies.remove(body) }
              }))
        }
      }
      Text("Both bodies must match an aspect filter.").font(.caption).foregroundStyle(.secondary)
    }
  }
}
