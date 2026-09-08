import HypergateCore
import SwiftUI

struct IntroductionView: View {
  let state: AppState
  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      Image(systemName: "moon.stars").font(.largeTitle).foregroundStyle(.purple)
        .accessibilityHidden(true)
      Text("Your sky, in the menu bar.").font(.title.bold())
      Text(
        "HypergateBar calculates planetary positions and events entirely on your Mac. No account, birth details, location permission, or internet connection is needed."
      )
      Text(
        "Closing Dashboard leaves HypergateBar running. If you remove the menu-bar item, macOS may quit the app. Reopen HypergateBar from Finder or Spotlight to restore it."
      )
      Text(
        "Alerts and launch at login start off. Enable them in Settings when you’re ready. Focus, sleep, shutdown, and macOS notification settings can delay or prevent delivery."
      ).foregroundStyle(.secondary)
      Button("Get started") {
        let p = state.preferences
        state.replacePreferences(
          AppPreferences(
            alerts: p.alerts, displayZone: p.displayZone, labelMode: p.labelMode,
            countdown: p.countdown,
            majorOrb: p.majorOrb, minorOrb: p.minorOrb, stationaryThreshold: p.stationaryThreshold,
            introduced: true))
        state.showIntroduction = false
      }.keyboardShortcut(.defaultAction)
    }.padding(30).frame(width: 500)
  }
}
