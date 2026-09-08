import Foundation
import Observation
import Sparkle

@MainActor @Observable
final class UpdateService {
  private var controller: SPUStandardUpdaterController?
  private(set) var status = "Updates disabled: publisher feed and key are not configured."
  var enabled: Bool { controller != nil }
  init(bundle: Bundle = .main) {
    guard bundle.object(forInfoDictionaryKey: "HypergatePublisherVerified") as? Bool == true,
      let feed = bundle.object(forInfoDictionaryKey: "SUFeedURL") as? String,
      let url = URL(string: feed), url.scheme == "https", url.host != nil,
      url.user == nil, url.password == nil,
      let key = bundle.object(forInfoDictionaryKey: "SUPublicEDKey") as? String,
      Data(base64Encoded: key)?.count == 32
    else { return }
    let updater = SPUStandardUpdaterController(
      startingUpdater: false, updaterDelegate: nil, userDriverDelegate: nil)
    controller = updater
    updater.startUpdater()
    status = "Updates configured for \(url.host ?? "publisher")."
  }
  func check() { controller?.checkForUpdates(nil) }
}
