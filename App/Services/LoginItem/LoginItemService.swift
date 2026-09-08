import Observation
import ServiceManagement

@MainActor @Observable
final class LoginItemService {
  var status = SMAppService.mainApp.status
  var error: String?
  var enabled: Bool { status == .enabled }
  func refresh() { status = SMAppService.mainApp.status }
  func setEnabled(_ value: Bool) {
    do {
      if value {
        try SMAppService.mainApp.register()
      } else {
        try SMAppService.mainApp.unregister()
      }
      error = nil
    } catch { self.error = String(describing: error) }
    refresh()
  }
  var statusText: String {
    switch status {
    case .enabled: "Registered"
    case .requiresApproval: "Approval required in System Settings → General → Login Items"
    case .notFound: "App registration unavailable; install the app in Applications"
    default: "Not registered"
    }
  }
}
