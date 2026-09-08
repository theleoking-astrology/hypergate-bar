import Foundation
import Observation
import Sparkle

enum UpdateEvent {
  case available(String)
  case notAvailable
  case failed(String)
  case capabilities(canCheck: Bool, automatic: Bool)
}

@MainActor protocol UpdateDriver: AnyObject {
  var onEvent: ((UpdateEvent) -> Void)? { get set }
  var automaticChecks: Bool { get set }
  func start()
  func check()
}

@MainActor @Observable
final class UpdateService {
  @ObservationIgnored private var driver: (any UpdateDriver)?
  private(set) var status = "Updates disabled: publisher feed and key are not configured."
  private(set) var availableVersion: String?
  private(set) var canCheck = false
  private(set) var automaticChecks = false
  var enabled: Bool { driver != nil }
  var updateAvailable: Bool { availableVersion != nil }
  var actionTitle: String {
    availableVersion.map { "Update to \($0)…" } ?? "Check for Updates…"
  }
  init(bundle: Bundle = .main) {
    guard bundle.object(forInfoDictionaryKey: "HypergatePublisherVerified") as? Bool == true,
      let feed = bundle.object(forInfoDictionaryKey: "SUFeedURL") as? String,
      let url = URL(string: feed), url.scheme == "https", url.host != nil,
      url.user == nil, url.password == nil,
      let key = bundle.object(forInfoDictionaryKey: "SUPublicEDKey") as? String,
      Data(base64Encoded: key)?.count == 32
    else { return }
    status = "Updates configured for \(url.host ?? "publisher")."
    connect(SparkleUpdateDriver())
  }
  // Injected drivers let tests exercise availability and install actions offline.
  init(driver: any UpdateDriver) {
    status = "Ready to check for updates."
    connect(driver)
  }
  private func connect(_ driver: any UpdateDriver) {
    self.driver = driver
    driver.onEvent = { [weak self] event in
      guard let self else { return }
      switch event {
      case .available(let version):
        availableVersion = version
        status = "HypergateBar \(version) is available. Choose Update to review and install it."
      case .notAvailable:
        availableVersion = nil
        status = "No compatible update is available."
      case .failed(let message):
        availableVersion = nil
        status = "Could not check for updates: \(message)"
      case .capabilities(let allowed, let automatic):
        canCheck = allowed
        automaticChecks = automatic
      }
    }
    driver.start()
  }
  func check() {
    guard canCheck else { return }
    status = updateAvailable ? "Opening the update…" : "Checking for updates…"
    driver?.check()
  }
  func setAutomaticChecks(_ enabled: Bool) {
    guard let driver else { return }
    driver.automaticChecks = enabled
    automaticChecks = enabled
  }
}

@MainActor private final class SparkleUpdateDriver: NSObject, UpdateDriver, SPUUpdaterDelegate {
  var onEvent: ((UpdateEvent) -> Void)?
  private var controller: SPUStandardUpdaterController?
  private var observation: NSKeyValueObservation?
  var automaticChecks: Bool {
    get { controller?.updater.automaticallyChecksForUpdates ?? false }
    set { controller?.updater.automaticallyChecksForUpdates = newValue }
  }
  override init() {
    super.init()
    let controller = SPUStandardUpdaterController(
      startingUpdater: false, updaterDelegate: self, userDriverDelegate: nil)
    self.controller = controller
    observation = controller.updater.observe(\.canCheckForUpdates, options: [.initial, .new]) {
      [weak self] _, change in
      let allowed = change.newValue ?? false
      Task { @MainActor in
        guard let self else { return }
        self.onEvent?(.capabilities(canCheck: allowed, automatic: self.automaticChecks))
      }
    }
  }
  func start() { controller?.startUpdater() }
  func check() { controller?.checkForUpdates(nil) }
  func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
    onEvent?(.available(item.displayVersionString))
  }
  func updaterDidNotFindUpdate(_ updater: SPUUpdater) { onEvent?(.notAvailable) }
  func updater(_ updater: SPUUpdater, didAbortWithError error: Error) {
    let failure = error as NSError
    if failure.domain == SUSparkleErrorDomain && failure.code == SUError.noUpdateError.rawValue {
      onEvent?(.notAvailable)
    } else {
      onEvent?(.failed(error.localizedDescription))
    }
  }
}
