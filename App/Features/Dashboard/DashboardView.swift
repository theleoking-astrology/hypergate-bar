import SwiftUI
import HypergateCore

struct DashboardView: View {
    let state: AppState
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("The sky, right now.").font(.largeTitle.weight(.semibold))
                    Text("HYPERGATEBAR · HYPERGATE AI OPEN SOURCE").font(.caption.weight(.medium)).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Refresh", systemImage: "arrow.clockwise") { Task { await state.refresh() } }
            }
            if let error = state.error { Text("Unavailable / stale: \(error)").foregroundStyle(.red) }
            if let sky = state.sky {
                HStack {
                    Label(sky.moonPhase ?? "Moon phase unavailable", systemImage: "moon")
                    Spacer()
                    Text(TimeZone.current.identifier)
                }.foregroundStyle(.secondary)
                Table(sky.positions) {
                    TableColumn("Planet") { position in
                        HStack {
                            Text(position.body.symbol).font(.title2).accessibilityHidden(true)
                            Text(position.body.name)
                        }
                    }
                    TableColumn("Sign") { Text($0.sign.name) }
                    TableColumn("Position") { Text($0.degreeText).monospacedDigit() }
                    TableColumn("Motion") { Text($0.motion()) }
                }
                if let ingress = state.nextMoonIngress {
                    HStack {
                        Text(ingress.title).font(.headline)
                        Spacer()
                        Text(ingress.instant, format: .dateTime.month(.abbreviated).day().hour().minute())
                    }
                }
                Text("Calculated \(sky.calculatedAt.formatted()) · Tropical · Geocentric · Offline")
                    .font(.caption).foregroundStyle(.secondary)
            } else { ProgressView("Calculating planetary positions…").frame(maxWidth: .infinity, maxHeight: .infinity) }
        }
        .padding(28)
        .frame(minWidth: 750, minHeight: 520)
        .tint(.purple)
    }
}
