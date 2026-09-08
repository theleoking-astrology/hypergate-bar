import SwiftUI

struct SettingsView: View {
    let state: AppState
    var body: some View {
        Form {
            Section("HypergateBar") {
                Text("Offline tropical, geocentric astrology.")
                Text("Development build · Astronomical accuracy validation in progress.").foregroundStyle(.secondary)
                Text("Closing Dashboard keeps the menu-bar app running. Reopen HypergateBar from Finder to recover access.")
            }
        }.formStyle(.grouped).padding().frame(width: 480, height: 250)
    }
}
