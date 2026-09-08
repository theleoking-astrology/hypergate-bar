import SwiftUI
import HypergateCore

struct MenuBarView: View {
    let state: AppState
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
            } else { Text("Calculating the sky…").foregroundStyle(.secondary) }
            if let event = state.nextMoonIngress {
                VStack(alignment: .leading, spacing: 4) {
                    Text("NEXT MOON INGRESS").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    Text(event.title)
                    Text(event.instant, format: .dateTime.month(.abbreviated).day().hour().minute())
                        .foregroundStyle(.secondary)
                }
            }
            if let error = state.error { Text("Unavailable / stale: \(error)").font(.caption).foregroundStyle(.red) }
            Divider()
            Button("Open Dashboard", action: AppDelegate.openDashboard).keyboardShortcut("d")
            SettingsLink { Text("Settings…") }.keyboardShortcut(",")
            Button("Refresh") { Task { await state.refresh() } }
            Divider()
            Button("Quit HypergateBar") { NSApplication.shared.terminate(nil) }.keyboardShortcut("q")
        }
        .padding(20)
        .frame(width: 340)
        .tint(.purple)
    }
}
